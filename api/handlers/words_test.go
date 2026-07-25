package handlers

import "testing"

// These tests cover words.go in isolation — the TSV parser and the data loaded
// from the embedded words.tsv. They need no database, so they always run.

func TestParseVocab_ParsesPairs(t *testing.T) {
	in := "# a theme comment\n" +
		"TRENO\tTRAIN\tm\n" +
		"\n" + // blank line
		"  BANCA\tBANK\tf  \n" + // surrounding whitespace is trimmed
		"# another comment\n" +
		"MELA\tAPPLE\tf\r\n" + // CRLF line ending is trimmed
		"VERDE\tGREEN\n" + // gender column omitted → ungendered
		"NOTABHERE\n" // no tab → skipped

	got := parseVocab(in)
	// a "#" line is not discarded: it names the theme of everything below it
	want := []vocab{
		{"TRENO", "TRAIN", "a theme comment", "m"},
		{"BANCA", "BANK", "a theme comment", "f"},
		{"MELA", "APPLE", "another comment", "f"},
		{"VERDE", "GREEN", "another comment", ""},
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

func TestGender_LoadedFromEmbeddedTSV(t *testing.T) {
	// masculine, feminine, and non-noun cases, including the irregulars a
	// final-vowel heuristic would get wrong (la mano, il problema, -ista nouns)
	for it, want := range map[string]string{
		"GATTO":    "m", // regular -o
		"ACQUA":    "f", // regular -a
		"MANO":     "f", // -o but feminine
		"FOTO":     "f", // -o but feminine
		"PROBLEMA": "m", // -a but masculine
		"POETA":    "m", // -a but masculine
		"TURISTA":  "m", // -ista
		"COLORE":   "m", // -e masculine noun
		"STAZIONE": "f", // -e feminine noun
		"RE":       "m", // short -e noun
		"ROSSO":    "",  // adjective, not a noun
		"MANGIARE": "",  // verb
		"CINQUE":   "",  // number
		"VERDE":    "",  // -e adjective
	} {
		if gender[it] != want {
			t.Errorf("gender[%q] = %q, want %q", it, gender[it], want)
		}
	}
	// every entry's map value matches its parsed field, and only m/f/"" occur
	for _, v := range words {
		if gender[v.Italian] != v.Gender {
			t.Errorf("gender[%q] = %q, want %q", v.Italian, gender[v.Italian], v.Gender)
		}
		if v.Gender != "" && v.Gender != "m" && v.Gender != "f" {
			t.Errorf("%q has invalid gender %q", v.Italian, v.Gender)
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
