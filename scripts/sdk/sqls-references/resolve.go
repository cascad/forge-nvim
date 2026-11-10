// Package references связывает SQL AST с объектами схемы, а не строками имён.
// Overlay пока не включён в SDK: CTE/DML/index и handler остаются задачами change.
package references

import (
	"fmt"
	"sort"
	"strings"

	"github.com/sqls-server/sqls/ast"
	"github.com/sqls-server/sqls/parser"
	"github.com/sqls-server/sqls/token"
)

// Table — снимок metadata выбранного connection. SQL здесь не выполняется.
type Table struct {
	Schema, Name string
	Columns      []string
}

type Occurrence struct {
	URI         string
	Start, End  token.Pos
	Symbol      string
	Declaration bool
	Problem     string
}

type Index struct{ Occurrences []Occurrence }

type binding struct {
	qualifier string
	table     Table
	symbol    string
	alias     string
}

type scope struct {
	parent   *scope
	bindings []binding
	uri      string
	index    *Index
	catalog  []Table
}

func folded(value string) string { return strings.ToLower(value) }
func tableSymbol(t Table) string { return "table:" + folded(t.Schema) + ":" + folded(t.Name) }

func significant(nodes []ast.Node) []ast.Node {
	out := make([]ast.Node, 0, len(nodes))
	for _, node := range nodes {
		if t, ok := node.(ast.Token); ok {
			switch t.GetToken().Kind {
			case token.Whitespace, token.Comment, token.MultilineComment, token.Semicolon:
				continue
			}
		}
		out = append(out, node)
	}
	return out
}

func keyword(node ast.Node) string {
	if t, ok := node.(ast.Token); ok && t.GetToken().Kind == token.SQLKeyword {
		return strings.ToUpper(node.String())
	}
	if node.Type() == ast.TypeMultiKeyword {
		return strings.ToUpper(node.String())
	}
	return ""
}

func identifiers(node ast.Node) []*ast.Identifier {
	if id, ok := node.(*ast.Identifier); ok {
		return []*ast.Identifier{id}
	}
	var out []*ast.Identifier
	if member, ok := node.(*ast.MemberIdentifier); ok {
		out = append(out, identifiers(member.Parent)...)
		out = append(out, identifiers(member.Child)...)
	}
	return out
}

func (s *scope) record(node ast.Node, symbol string, declaration bool, problem error) {
	row := Occurrence{URI: s.uri, Start: node.Pos(), End: node.End(), Symbol: symbol, Declaration: declaration}
	if problem != nil {
		row.Problem = problem.Error()
	}
	s.index.Occurrences = append(s.index.Occurrences, row)
}

func (s *scope) source(node ast.Node) error {
	if list, ok := node.(*ast.IdentifierList); ok {
		for _, item := range list.Identifiers {
			if err := s.source(item); err != nil {
				return err
			}
		}
		return nil
	}
	var alias *ast.Identifier
	if named, ok := node.(*ast.Aliased); ok {
		alias, _ = named.AliasedName.(*ast.Identifier)
		if alias == nil {
			return fmt.Errorf("SQL references: неизвестное объявление alias")
		}
		node = named.RealName
	}
	parts := identifiers(node)
	if len(parts) < 1 || len(parts) > 2 {
		return fmt.Errorf("SQL references: этот relation source пока не поддержан: %s", node.String())
	}
	name := parts[len(parts)-1].NoQuoteString()
	var candidates []Table
	for _, table := range s.catalog {
		if !strings.EqualFold(table.Name, name) {
			continue
		}
		if len(parts) == 2 && !strings.EqualFold(table.Schema, parts[0].NoQuoteString()) {
			continue
		}
		candidates = append(candidates, table)
	}
	if len(candidates) != 1 {
		return fmt.Errorf("SQL references: таблица %s не разрешена однозначно в схеме", node.String())
	}
	table := candidates[0]
	entry := binding{table: table, qualifier: name, symbol: tableSymbol(table)}
	s.record(parts[len(parts)-1], entry.symbol, false, nil)
	if alias != nil {
		entry.qualifier = alias.NoQuoteString()
		entry.alias = fmt.Sprintf("alias:%s:%d:%d", s.uri, alias.Pos().Line, alias.Pos().Col)
		s.record(alias, entry.alias, true, nil)
	}
	for _, existing := range s.bindings {
		if strings.EqualFold(existing.qualifier, entry.qualifier) {
			return fmt.Errorf("SQL references: повторный relation alias %s", entry.qualifier)
		}
	}
	s.bindings = append(s.bindings, entry)
	return nil
}

func (s *scope) column(qualifier, name string) (string, *binding, error) {
	for current := s; current != nil; current = current.parent {
		var matches []struct {
			symbol string
			owner  *binding
		}
		qualified := false
		for i := range current.bindings {
			entry := &current.bindings[i]
			if qualifier != "" && !strings.EqualFold(entry.qualifier, qualifier) {
				continue
			}
			qualified = qualified || qualifier != ""
			for _, col := range entry.table.Columns {
				if strings.EqualFold(col, name) {
					matches = append(matches, struct {
						symbol string
						owner  *binding
					}{entry.symbol + ":column:" + folded(col), entry})
				}
			}
		}
		if len(matches) > 1 {
			return "", nil, fmt.Errorf("SQL references: неоднозначная колонка %s", name)
		}
		if len(matches) == 1 {
			return matches[0].symbol, matches[0].owner, nil
		}
		// Локальный alias перекрывает внешний даже без нужной колонки.
		if qualified {
			break
		}
	}
	return "", nil, fmt.Errorf("SQL references: колонка %s не разрешена в этой области", name)
}

func (s *scope) walk(node ast.Node) error {
	switch item := node.(type) {
	case *ast.MemberIdentifier:
		parts := identifiers(item)
		if len(parts) != 2 {
			return fmt.Errorf("SQL references: qualified expression пока не поддержано: %s", item.String())
		}
		symbol, owner, err := s.column(parts[0].NoQuoteString(), parts[1].NoQuoteString())
		s.record(parts[1], symbol, false, err)
		if owner != nil {
			parentSymbol := owner.symbol
			if owner.alias != "" {
				parentSymbol = owner.alias
			}
			s.record(parts[0], parentSymbol, false, nil)
		}
		return nil
	case *ast.Identifier:
		if !item.IsWildcard() {
			symbol, _, err := s.column("", item.NoQuoteString())
			s.record(item, symbol, false, err)
		}
		return nil
	case *ast.Aliased:
		// Projection alias получает собственную identity; не физическую колонку.
		if err := s.walk(item.RealName); err != nil {
			return err
		}
		if alias, ok := item.AliasedName.(*ast.Identifier); ok {
			s.record(alias, fmt.Sprintf("projection:%s:%d:%d", s.uri, alias.Pos().Line, alias.Pos().Col), true, nil)
		}
		return nil
	case *ast.Parenthesis:
		nodes := significant(item.Inner().GetTokens())
		if len(nodes) > 0 && (keyword(nodes[0]) == "SELECT" || keyword(nodes[0]) == "WITH") {
			return s.selectScope(nodes)
		}
	case *ast.FunctionLiteral:
		// Имя функции не является unqualified column; аргументы обходятся отдельно.
		for _, child := range item.GetTokens() {
			if _, ok := child.(*ast.Parenthesis); ok {
				if err := s.walk(child); err != nil {
					return err
				}
			}
		}
		return nil
	}
	if list, ok := node.(ast.TokenList); ok {
		for _, child := range list.GetTokens() {
			if err := s.walk(child); err != nil {
				return err
			}
		}
	}
	return nil
}

func (parent *scope) selectScope(nodes []ast.Node) error {
	nodes = significant(nodes)
	if len(nodes) == 0 {
		return nil
	}
	if keyword(nodes[0]) != "SELECT" {
		return fmt.Errorf("SQL references: statement %s пока не поддержан resolver", keyword(nodes[0]))
	}
	s := &scope{parent: parent, uri: parent.uri, index: parent.index, catalog: parent.catalog}
	sources := make(map[ast.Node]bool)
	for i, node := range nodes {
		word := keyword(node)
		if word == "UNION" || word == "UNION ALL" || word == "INTERSECT" || word == "EXCEPT" {
			return fmt.Errorf("SQL references: set expression пока не поддержано resolver")
		}
		if word == "FROM" || word == "JOIN" || strings.HasSuffix(word, " JOIN") {
			if i+1 >= len(nodes) {
				return fmt.Errorf("SQL references: отсутствует relation source")
			}
			if err := s.source(nodes[i+1]); err != nil {
				return err
			}
			sources[nodes[i+1]] = true
		}
	}
	for _, node := range nodes {
		if !sources[node] {
			if err := s.walk(node); err != nil {
				return err
			}
		}
	}
	return nil
}

func Build(documents map[string]string, catalog []Table) (*Index, error) {
	index := &Index{}
	var uris []string
	for uri := range documents {
		uris = append(uris, uri)
	}
	sort.Strings(uris)
	for _, uri := range uris {
		parsed, err := parser.Parse(documents[uri])
		if err != nil {
			return nil, fmt.Errorf("SQL references: %s: %w", uri, err)
		}
		root := &scope{uri: uri, index: index, catalog: catalog}
		for _, node := range parsed.GetTokens() {
			if statement, ok := node.(*ast.Statement); ok {
				if err := root.selectScope(statement.GetTokens()); err != nil {
					return nil, fmt.Errorf("%s: %w", uri, err)
				}
			}
		}
	}
	return index, nil
}

func (index *Index) Find(uri string, pos token.Pos, includeDeclaration bool) ([]Occurrence, error) {
	var symbol string
	for _, row := range index.Occurrences {
		if row.URI == uri && token.ComparePos(row.Start, pos) <= 0 && token.ComparePos(pos, row.End) < 0 {
			if row.Problem != "" {
				return nil, fmt.Errorf("%s", row.Problem)
			}
			symbol = row.Symbol
			break
		}
	}
	if symbol == "" {
		return nil, fmt.Errorf("SQL references: под курсором нет разрешённого символа")
	}
	out := make([]Occurrence, 0)
	for _, row := range index.Occurrences {
		if row.Symbol == symbol && (includeDeclaration || !row.Declaration) {
			out = append(out, row)
		}
	}
	sort.Slice(out, func(i, j int) bool {
		if out[i].URI != out[j].URI {
			return out[i].URI < out[j].URI
		}
		return token.ComparePos(out[i].Start, out[j].Start) < 0
	})
	return out, nil
}
