package references

import (
	"reflect"
	"strings"
	"testing"
	"unicode/utf8"

	"github.com/sqls-server/sqls/token"
)

var testCatalog = []Table{
	{Schema: "main", Name: "users", Columns: []string{"id", "name"}},
	{Schema: "main", Name: "accounts", Columns: []string{"id", "owner_id"}},
}

func at(text, match string, occurrence int, advance int) token.Pos {
	start := 0
	for i := 0; i <= occurrence; i++ {
		n := strings.Index(text[start:], match)
		if n < 0 {
			panic("не найден fixture token: " + match)
		}
		start += n
		if i < occurrence {
			start += len(match)
		}
	}
	start += advance
	before := text[:start]
	line := strings.Count(before, "\n")
	return token.Pos{Line: line, Col: utf8.RuneCountInString(before[strings.LastIndex(before, "\n")+1:])}
}

func TestColumnsHaveSchemaIdentity(t *testing.T) {
	a := "SELECT '😀 id u.id', u.id, a.id FROM users u JOIN accounts a ON a.owner_id=u.id; -- u.id\nSELECT id FROM users JOIN accounts ON users.id=accounts.id;"
	b := "SELECT person.id FROM users person WHERE person.id=1;"
	index, err := Build(map[string]string{"a.sql": a, "b.sql": b}, testCatalog)
	if err != nil {
		t.Fatal(err)
	}
	rows, err := index.Find("a.sql", at(a, "u.id", 1, 2), false)
	if err != nil {
		t.Fatal(err)
	}
	var got []string
	for _, row := range rows {
		got = append(got, row.URI)
	}
	if !reflect.DeepEqual(got, []string{"a.sql", "a.sql", "a.sql", "b.sql", "b.sql"}) {
		t.Fatalf("physical identity: %+v", rows)
	}
	if rows[0].Start != at(a, "u.id", 1, 2) {
		t.Fatalf("Unicode range: %+v", rows[0])
	}
	_, err = index.Find("a.sql", at(a, "SELECT id", 0, 7), false)
	if err == nil || !strings.Contains(err.Error(), "неоднозначная") {
		t.Fatalf("ambiguous column: %v", err)
	}
	if _, err = index.Find("a.sql", at(a, "u.id", 0, 2), false); err == nil {
		t.Fatal("literal is not a symbol")
	}
}

func TestNestedAliasShadowingAndCorrelation(t *testing.T) {
	text := "SELECT u.id FROM users u WHERE EXISTS (SELECT u.id FROM accounts u WHERE u.owner_id>0) AND EXISTS (SELECT a.id FROM accounts a WHERE a.owner_id=u.id);"
	index, err := Build(map[string]string{"a.sql": text}, testCatalog)
	if err != nil {
		t.Fatal(err)
	}
	outer, err := index.Find("a.sql", at(text, "u.id", 0, 2), false)
	if err != nil || len(outer) != 2 {
		t.Fatalf("outer/correlated: %+v %v", outer, err)
	}
	inner, err := index.Find("a.sql", at(text, "u.id", 1, 2), false)
	if err != nil || len(inner) != 2 {
		t.Fatalf("accounts.id includes separate a.id: %+v %v", inner, err)
	}
	alias, err := index.Find("a.sql", at(text, "users u", 0, 6), true)
	if err != nil || len(alias) != 3 {
		t.Fatalf("alias declaration+two outer usages: %+v %v", alias, err)
	}
	uses, err := index.Find("a.sql", at(text, "users u", 0, 6), false)
	if err != nil || len(uses) != 2 {
		t.Fatalf("includeDeclaration=false: %+v %v", uses, err)
	}
}

func TestLocalAliasWithoutColumnDoesNotFallThrough(t *testing.T) {
	text := "SELECT u.name FROM users u WHERE EXISTS (SELECT u.name FROM accounts u);"
	index, err := Build(map[string]string{"a.sql": text}, testCatalog)
	if err != nil {
		t.Fatal(err)
	}
	if rows, err := index.Find("a.sql", at(text, "u.name", 1, 2), false); err == nil {
		t.Fatalf("shadowed missing column: %+v", rows)
	}
}

func TestUnknownRelationDoesNotReturnPartialIndex(t *testing.T) {
	documents := map[string]string{"a.sql": "SELECT id FROM users;", "b.sql": "SELECT id FROM missing_table;"}
	if index, err := Build(documents, testCatalog); err == nil || index != nil {
		t.Fatalf("неполный индекс не является успешным результатом: %+v %v", index, err)
	}
}
