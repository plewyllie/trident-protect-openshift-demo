# Shared helpers for the convenience scripts. The scripts only apply the YAML files in
# this repo; render fills in their ${PLACEHOLDER}s.
REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
SRC_NS=webapp-demo-napp
DR_NS=webapp-demo-napp-dr
TP_NS=trident-protect

# render FILE NAME=value ... : print FILE with ${NAME} replaced (not in comment lines).
# A placeholder alone on its line may hold a multi-line value (e.g. a PEM certificate);
# every line gets its indent.
render() {
  local file=$1; shift
  env "$@" awk -v names="${*%%=*}" '
    BEGIN { n = split(names, k, " ") }
    /^[ \t]*#/ { print; next }   # leave comments (which document the placeholders) alone
    {
      line = $0
      for (i = 1; i <= n; i++) {
        ph = "${" k[i] "}"; v = ENVIRON[k[i]]
        p = index(line, ph)
        if (p == 0) continue
        if (line ~ "^[ \t]*\\$\\{" k[i] "\\}[ \t]*$") {
          ind = substr(line, 1, p - 1); m = split(v, vl, "\n"); line = ""
          for (j = 1; j <= m; j++) line = line (j > 1 ? "\n" : "") ind vl[j]
        } else {
          while ((p = index(line, ph)) > 0) line = substr(line, 1, p - 1) v substr(line, p + length(ph))
        }
      }
      print line
    }' "$file"
}

# wait_for KIND/NAME NAMESPACE JSONPATH VALUE [TRIES]: poll every 10s until JSONPATH == VALUE
wait_for() {
  local i v
  for i in $(seq 1 "${5:-60}"); do
    v=$(oc get "$1" -n "$2" -o jsonpath="$3" 2>/dev/null || true)
    echo "  $1: ${v:-pending}"
    [ "$v" = "$4" ] && return 0
    case "$v" in Failed|Error|failed) oc get "$1" -n "$2" -o jsonpath='{.status.error}{"\n"}' 2>/dev/null; return 1 ;; esac
    sleep 10
  done
  echo "Timed out waiting for $1 to reach $4"; return 1
}

service_ca() { oc get cm openshift-service-ca.crt -n "$TP_NS" -o jsonpath='{.data.service-ca\.crt}'; }
bucket_name() { oc get cm "$1" -n "$TP_NS" -o jsonpath='{.data.BUCKET_NAME}'; }
app_url() { echo "https://$(oc get route frontend -n "$1" -o jsonpath='{.spec.host}')"; }
