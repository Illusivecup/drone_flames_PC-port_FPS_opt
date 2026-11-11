class_name NetTls
extends RefCounted










const ROOTS: String = "res://net/tls/backend_roots.crt"
const RELAY_ROOT: String = "res://net/tls/df_relay_root.crt"
const PINNED_SUFFIX: String = "snaipix.com"

static var _opts: TLSOptions = null
static var _relay_opts: TLSOptions = null



static func for_url(url: String) -> TLSOptions:
	if not (url.begins_with("https://") or url.begins_with("wss://")):
		return null
	var host: String = url.get_slice("://", 1).get_slice("/", 0).get_slice(":", 0).to_lower()
	if host == "45.145.12.165":
		if _relay_opts == null:
			var relay_root: = X509Certificate.new()
			if relay_root.load(RELAY_ROOT) == OK:
				_relay_opts = TLSOptions.client_unsafe(relay_root)
			else:
				_relay_opts = TLSOptions.client_unsafe()
		return _relay_opts
	if host != PINNED_SUFFIX and not host.ends_with("." + PINNED_SUFFIX):
		return null
	if _opts == null:
		var roots: = X509Certificate.new()
		if roots.load(ROOTS) != OK:
			push_error("[NetTls] %s missing: the backend is refused (pinning cannot fall back to the system roots)" % ROOTS)
			roots = X509Certificate.new()
		_opts = TLSOptions.client(roots)
	return _opts
