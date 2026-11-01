#!/usr/bin/env bash
# Smoke tests for the Hugo site. Run against a locally served instance:
#   hugo server --port 1313 &
#   ./scripts/smoke_test.sh
# Override the target with SMOKE_BASE_URL (default http://localhost:1313).
set -uo pipefail

BASE_URL="${SMOKE_BASE_URL:-http://localhost:1313}"
FAILURES=0
PASSED=0

pass() { PASSED=$((PASSED + 1)); echo "PASS: $1"; }
fail() { FAILURES=$((FAILURES + 1)); echo "FAIL: $1"; }

# check_page <path> <expected_http_code> [expected_substring]
check_page() {
  local path="$1" expected_code="$2" substring="${3:-}"
  local body code
  body="$(curl -sL -w '\n%{http_code}' "${BASE_URL}${path}")"
  code="$(printf '%s' "$body" | tail -n1)"
  if [[ "$code" != "$expected_code" ]]; then
    fail "${path} returned HTTP ${code}, expected ${expected_code}"
    return
  fi
  if [[ -n "$substring" ]] && ! printf '%s' "$body" | grep -qi "$substring"; then
    fail "${path} does not contain '${substring}'"
    return
  fi
  pass "${path} -> ${expected_code}${substring:+ and contains '${substring}'}"
}

echo "=== Smoke tests against ${BASE_URL} ==="

# 1. Key pages render with HTTP 200 and expected content
check_page "/"                 200 "My Bioinformatics Blog"
check_page "/about/"           200 "About"
check_page "/cv/"              200 "CV"
check_page "/posts/"           200

# 2. All blog posts are published and reachable
for slug in formal-verification-for-beginners alloy-in-practice causal-ml-intro; do
  check_page "/posts/${slug}/" 200
done

# 3. Navigation menu items present on the home page
home="$(curl -sL "${BASE_URL}/")"
for item in 'title="Home"' 'title="About"' 'title="CV"' 'title="Links"'; do
  if printf '%s' "$home" | grep -qi "$item"; then
    pass "home page contains nav item ${item}"
  else
    fail "home page missing nav item ${item}"
  fi
done

# 4. LinkedIn link is wired into the Links dropdown; ResearchGate is gone
if printf '%s' "$home" | grep -qi "linkedin.com/in/ruslan-bogdanov-software-dev"; then
  pass "home page links to personal LinkedIn"
else
  fail "home page does not link to personal LinkedIn"
fi
if printf '%s' "$home" | grep -qi "researchgate"; then
  fail "home page still links to ResearchGate (should be removed)"
else
  pass "no ResearchGate link"
fi

# 5. The three feature posts each show a reading-time label of at least 10 minutes
for slug in formal-verification-for-beginners alloy-in-practice causal-ml-intro; do
  post_page="$(curl -sL "${BASE_URL}/posts/${slug}/")"
  minutes="$(printf '%s' "$post_page" | grep -oiE '[0-9]+ min read' | grep -oE '[0-9]+' | head -n1)"
  if [[ -z "$minutes" ]]; then
    fail "post ${slug} has no reading-time label"
  elif (( minutes < 10 )); then
    fail "post ${slug} shows ${minutes} min read (expected >= 10)"
  else
    pass "post ${slug} shows ${minutes} min read"
  fi
done

# 6. Theme fingerprint: Hugo generator meta tag present
if printf '%s' "$home" | grep -qi 'name="generator" content="Hugo'; then
  pass "Hugo generator meta tag present"
else
  fail "Hugo generator meta tag missing"
fi

# 7. Static assets: theme CSS bundle loads
css_path="$(printf '%s' "$home" | grep -oE 'href="[^"]*\.css[^"]*"' | head -n1 | sed 's/href="//; s/"$//')"
if [[ -n "$css_path" ]]; then
  case "$css_path" in
    http*) css_url="$css_path" ;;
    *)     css_url="${BASE_URL}${css_path}" ;;
  esac
  css_code="$(curl -sL -o /dev/null -w '%{http_code}' "$css_url")"
  if [[ "$css_code" == "200" ]]; then
    pass "stylesheet ${css_path} loads"
  else
    fail "stylesheet ${css_path} returned HTTP ${css_code}"
  fi
else
  fail "no stylesheet link found on home page"
fi

echo "=== ${PASSED} passed, ${FAILURES} failed ==="
if (( FAILURES > 0 )); then exit 1; fi
exit 0
