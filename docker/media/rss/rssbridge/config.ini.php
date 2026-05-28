; RSSBridge configuration
; Reference: https://rss-bridge.org/bridge_list

[system]
; Enable/disable the bridge list on the homepage
enable_maintenance_mode = false

[cache]
; Use file cache to reduce repeated scraping
type = "file"
; Cache timeout in seconds (default 3600 = 1 hour)
timeout = 3600

[proxy]
; Optional: set an HTTP proxy for bridges that need it
; url = "http://proxy:8888"
; by_bridge = false

[authentication]
; Uncomment and set to restrict RSSBridge to specific users
; enable = true
; username = "admin"
; password = "changeme"
