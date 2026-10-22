# gm-paths.jq — THE implementation of specclaw's canonical field-path language
# (templates/CONTRACT.md (g)) and divergence classification (CONTRACT.md (j.1)).
#
# Loaded from disk and prepended to the jq program by BOTH
# `specclaw-bf-baseline` (record-time validation of every fixture's
# normalized_fields) and `specclaw-bf-replay` (compare-time exclusion, the
# actual-output normalization WARN, and per-diff classification). One file, two
# callers — never a second lookalike copy inside a bin. A capture-time
# validator that disagrees with the compare-time matcher about what a path
# means is exactly the failure this file exists to make impossible: the path
# validates green at record time and then silently normalizes nothing on every
# replay.
#
# It is loaded by concatenation (`jq "$GM_PATHS_JQ"'<program>'`) rather than by
# `jq -L`/`include`, deliberately: the plugin root is a shell-computed path and
# passing it through jq's module search on a Windows/MSYS toolchain is a path-
# translation hazard the concatenation approach simply doesn't have.
#
# Every definition here is pure jq over declared data. Nothing in this file
# knows what stack produced the JSON it is reading, and nothing in it may ever
# name a framework, an exception class, or a project's error code.

# ── Primitives ───────────────────────────────────────────────────────────────

# A PREDICATE, not a `select`. `paths(f)` feeds each value through f and keeps
# the path when f's output is truthy — so the obvious-looking
# `select(type != "array" and type != "object")` passes the VALUE through, and
# a field holding `null` or `false` is judged falsy and silently vanishes from
# every path walk. That is not hypothetical here: `threw: false` and
# `error_code: null` (CONTRACT.md (b.1)) are the two most important fields in
# the whole comparison. Returning a boolean is what makes them visible.
def gm_scalars: (type != "array" and type != "object");

# Safe read: an intermediate segment of the wrong type yields null rather than
# aborting the whole program. Two outputs being compared genuinely can disagree
# about whether `a` is an object or a string — that is a divergence to report,
# not a crash.
def gm_getpath_safe($obj; $p): (try ($obj | getpath($p)) catch null);

def gm_field_or_null($obj; $name):
  if ($obj | type) == "object" and ($obj | has($name)) then $obj[$name] else null end;

# A jq path array -> the canonical string. Indices attach to their key with no
# separating dot: ["cases", 0, "invoice_id"] -> "cases[0].invoice_id".
def gm_render_path($p):
  reduce $p[] as $seg (
    "";
    if ($seg | type) == "number" then . + "[\($seg)]"
    elif . == "" then ($seg | tostring)
    else . + "." + ($seg | tostring)
    end
  );

# Both a concrete jq path and a written pattern reduce to the same flat token
# list, so matching is one element-wise comparison. Keys and indices are tagged
# so a key that happens to look like a number can never match an index.
def gm_tokens_of_jqpath($p):
  [ $p[] | if type == "number" then "i:\(.)" else "k:\(.)" end ];

# `output.` is not canonical syntax (paths are rooted AT the output object) but
# it resolves unambiguously, so it is stripped rather than rejected. The caller
# reports the canonical spelling.
def gm_canon_pattern($s): ($s | tostring) | sub("^output\\."; "");

def gm_tokens_of_pattern($s):
  gm_canon_pattern($s)
  | if . == "" then []
    else
      [ split(".")[]
        | capture("^(?<key>[^\\[]*)(?<idx>(?:\\[[^\\]]*\\])*)$")
        | ( select(.key != "") | "k:\(.key)" ),
          ( .idx | scan("\\[([^\\]]*)\\]") | "i:\(.[0])" )
      ]
    end;

def gm_tok_match($pt; $ct):
  ($pt == $ct) or (($pt == "i:*") and ($ct | startswith("i:")));

# CONTRACT.md (g): a pattern matches a concrete path when it is EQUAL TO or a
# PROPER PREFIX OF it, segment for segment. Prefix semantics are what let one
# entry naming an object or array normalize its whole subtree.
def gm_pattern_matches($ptoks; $ctoks):
  ($ptoks | length) as $n
  | if $n == 0 then true
    elif ($ctoks | length) < $n then false
    else ([ range(0; $n) | gm_tok_match($ptoks[.]; $ctoks[.]) ] | all)
    end;

# Every scalar leaf's path, relative to the output object. The {value:} wrapper
# is what makes a scalar-or-null output representable at all (it has no paths
# of its own); `.[1:]` strips the wrapper back off.
def gm_concrete_paths($output):
  {value: $output} | [ paths(gm_scalars) ] | map(.[1:]);

def gm_last_key($toks):
  ([ $toks[] | select(startswith("k:")) ] | last // "k:") | ltrimstr("k:");

# ── Resolution and validation ────────────────────────────────────────────────

def gm_resolve($pattern; $output):
  gm_tokens_of_pattern($pattern) as $pt
  | [ gm_concrete_paths($output)[]
      | select(gm_pattern_matches($pt; gm_tokens_of_jqpath(.)))
      | gm_render_path(.) ];

# For a path that matched nothing: the paths that DO exist and plausibly meant.
# Exact leaf-name matches first ("credit_note_id" -> "result.credit_note_id");
# failing that, leaf names containing it. Purely lexical, capped, and offered
# as a suggestion — never applied automatically.
# Case- and separator-insensitive form, so a rebuild that renamed
# `credit_note_id` to `creditNoteId` — by far the most common shape change
# across a rebuild — still gets suggested rather than silently coming back
# with no candidate at all.
def gm_leafkey_norm: ascii_downcase | gsub("[_-]"; "");

def gm_near_misses($pattern; $output):
  gm_last_key(gm_tokens_of_pattern($pattern)) as $leaf
  | ($leaf | gm_leafkey_norm) as $nleaf
  | [ gm_concrete_paths($output)[] | {p: ., t: gm_tokens_of_jqpath(.)} ] as $all
  | [ $all[] | select(gm_last_key(.t) == $leaf) | gm_render_path(.p) ] as $exact
  | ( if ($exact | length) > 0 then $exact
      elif $leaf == "" then []
      else
        ( [ $all[] | select((gm_last_key(.t) | gm_leafkey_norm) == $nleaf)
            | gm_render_path(.p) ] ) as $renamed
        | if ($renamed | length) > 0 then $renamed
          else [ $all[]
                 | select((gm_last_key(.t) | gm_leafkey_norm) | contains($nleaf))
                 | gm_render_path(.p) ]
          end
      end )
  | .[0:5];

# One row per declared normalized_fields entry. `matches: 0` is a dead path:
# a hard error at record time, a reported WARN at compare time.
def gm_resolution_report($normalized; $output):
  [ ($normalized // [])[]
    | . as $raw
    | gm_resolve($raw; $output) as $hits
    | { path: $raw,
        canonical: gm_canon_pattern($raw),
        matches: ($hits | length),
        suggestions: (if ($hits | length) == 0
                      then gm_near_misses($raw; $output) else [] end) } ];

# ── Error-outcome contract (CONTRACT.md (b.1), (h)) ──────────────────────────

def gm_has_leaf($output; $name):
  ( ($output | type) == "object" and ($output | has($name)) )
  or ( [ gm_concrete_paths($output)[]
         | select(gm_last_key(gm_tokens_of_jqpath(.)) == $name) ] | length ) > 0;

# NOTE the deliberate absence of `//` anywhere a found value is returned:
# `threw` is legitimately `false` and `false // null` is `null`. An alternative
# operator here would report every non-throwing capture as "no value recorded".
def gm_find_leaf($output; $name):
  gm_field_or_null($output; $name) as $top
  | if $top != null then $top
    else ( [ gm_concrete_paths($output)[]
             | select(gm_last_key(gm_tokens_of_jqpath(.)) == $name)
             | gm_getpath_safe($output; .) ]
           | if length == 0 then null else .[0] end )
    end;

def gm_outcome_summary($output):
  { outcome:    gm_find_leaf($output; "outcome"),
    error_code: gm_find_leaf($output; "error_code"),
    threw:      gm_find_leaf($output; "threw") };

# Every error_code leaf paired with its sibling outcome — the pairing that
# decides both the record-time "REJECTED with no code" check and the
# compare-time unmapped-error-code class.
def gm_error_facts($output):
  [ gm_concrete_paths($output)[]
    | select(gm_last_key(gm_tokens_of_jqpath(.)) == "error_code")
    | { path: gm_render_path(.),
        error_code: gm_getpath_safe($output; .),
        outcome: gm_getpath_safe($output; .[0:-1] + ["outcome"]) } ];

# Codes actually asserted by this output — what record cross-checks against the
# project's own error-map.md.
def gm_declared_codes($output):
  [ gm_error_facts($output)[] | .error_code | select(. != null) ] | unique;

# Paths where the seam recorded a rejection but no semantic code. Legal ONLY
# when the scenario is marked PROVISIONAL, i.e. an agent asked instead of
# guessing (CONTRACT.md (h)); the caller applies that rule.
def gm_unmapped_rejections($output):
  [ gm_error_facts($output)[]
    | select(.outcome == "REJECTED" and .error_code == null) | .path ];

# ── Classification (CONTRACT.md (j.1)) ───────────────────────────────────────

def gm_representation_names:
  ["ExceptionType", "InnerExceptionType", "ExceptionMessage", "InnerExceptionMessage"];

# The identifier after the last ".", "::" or "/" — whichever qualified-name
# convention the producing stack used.
def gm_shortname: if type == "string" then (split("\\.|::|/"; "") | last) else . end;

def gm_field_class($p; $ev; $av; $expected; $actual):
  gm_last_key(gm_tokens_of_jqpath($p)) as $leaf
  | if (gm_representation_names | index($leaf)) != null then
      "representation"
    elif $leaf == "error_code"
         and ( ($ev == null and (gm_getpath_safe($expected; $p[0:-1] + ["outcome"]) == "REJECTED"))
               or ($av == null and (gm_getpath_safe($actual; $p[0:-1] + ["outcome"]) == "REJECTED")) ) then
      "unmapped-error-code"
    else
      "behavioural"
    end;

# The field-by-field diff. Normalized paths are dropped outright; everything
# surviving carries the class that decides whether it can FAIL a run.
def gm_diffs($expected; $actual; $normalized):
  [ ($normalized // [])[] | gm_tokens_of_pattern(.) ] as $npats
  | {value: $expected} as $ew
  | {value: $actual} as $aw
  | ( ([ $ew | paths(gm_scalars) ] + [ $aw | paths(gm_scalars) ]) | unique ) as $all
  | [ $all[]
      | .[1:] as $p
      | gm_tokens_of_jqpath($p) as $ct
      | select( ([ $npats[] | gm_pattern_matches(.; $ct) ] | any) | not )
      | gm_render_path($p) as $raw
      | (if $raw == "" then "(root)" else $raw end) as $pstr
      | gm_getpath_safe($ew; ["value"] + $p) as $ev
      | gm_getpath_safe($aw; ["value"] + $p) as $av
      | (if ($pstr | endswith("ExceptionType")) then ($ev | gm_shortname) else $ev end) as $evc
      | (if ($pstr | endswith("ExceptionType")) then ($av | gm_shortname) else $av end) as $avc
      | select($evc != $avc)
      | { field_path: $pstr,
          expected: $ev,
          actual: $av,
          field_class: gm_field_class($p; $ev; $av; $expected; $actual) } ];

# Row class = highest-precedence field class present (CONTRACT.md (j.2)).
def gm_divergence_class($diffs):
  ( [ $diffs[] | .field_class ] ) as $c
  | if ($c | length) == 0 then null
    elif ($c | index("behavioural")) != null then "behavioural"
    elif ($c | index("unmapped-error-code")) != null then "unmapped-error-code"
    else "representation"
    end;
