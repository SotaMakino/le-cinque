package handlers

import "testing"

// These tests cover words.go in isolation — the TSV parser and the data loaded
// from the embedded words.tsv. They need no database, so they always run.

func TestParseVocab_ParsesPairs(t *testing.T) {
	in := "# a theme comment\n" +
		"TRENO\tTRAIN\n" +
		"\n" + // blank line
		"  BANCA\tBANK  \n" + // surrounding whitespace is trimmed
		"# another comment\n" +
		"MELA\tAPPLE\r\n" + // CRLF line ending is trimmed
		"MUSICA\tMUSIC\n" +
		"NOTABHERE\n" // no tab → skipped

	got := parseVocab(in)
	want := []vocab{
		{"TRENO", "TRAIN"},
		{"BANCA", "BANK"},
		{"MELA", "APPLE"},
		{"MUSICA", "MUSIC"},
	}
	if len(got) != len(want) {
		t.Fatalf("expected %d entries, got %d: %+v", len(want), len(got), got)
	}
	for i, w := range want {
		if got[i] != w {
			t.Errorf("entry %d: expected %+v, got %+v", i, w, got[i])
		}
	}
}

func TestParseVocab_SkipsCommentsAndBlanks(t *testing.T) {
	if got := parseVocab("# only comments\n\n   \n#more\n"); len(got) != 0 {
		t.Errorf("expected no entries, got %+v", got)
	}
	if got := parseVocab(""); len(got) != 0 {
		t.Errorf("empty input should yield no entries, got %+v", got)
	}
}

func TestWords_LoadedFromEmbeddedTSV(t *testing.T) {
	if len(words) < 1500 {
		t.Errorf("expected 1500+ words from the embedded TSV, got %d", len(words))
	}
	// a few known entries survive the round-trip through words.tsv
	for it, en := range map[string]string{"TRENO": "TRAIN", "GATTO": "CAT", "FENDITURA": "SLIT"} {
		if english[it] != en {
			t.Errorf("expected %q → %q, got %q", it, en, english[it])
		}
	}
}

func TestEnglishMap_MatchesWords(t *testing.T) {
	// unique Italian keys (see TestWords_UppercaseAndUnique) → one map entry each
	if len(english) != len(words) {
		t.Errorf("english map has %d entries, words has %d", len(english), len(words))
	}
	for _, v := range words {
		if english[v.Italian] != v.English {
			t.Errorf("english[%q] = %q, want %q", v.Italian, english[v.Italian], v.English)
		}
	}
}
