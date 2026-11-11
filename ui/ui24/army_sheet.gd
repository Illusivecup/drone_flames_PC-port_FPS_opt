extends PanelContainer



var ux: Node


func close() -> void :
	if ux != null and is_instance_valid(ux) and ux.get("sheet") == self:
		ux.call("close_view")
