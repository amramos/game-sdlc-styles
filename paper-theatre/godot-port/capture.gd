extends Node
## Autoload: waits a few frames, saves the root viewport to --out=<png>, quits.
## Integer-upscales (nearest) to 1280 wide when the viewport renders at a smaller base.

func _ready() -> void:
	Engine.max_fps = 10   # machine rule: no 60 fps idle redraw
	var out := ""
	var frames := 12
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--frames="):
			frames = int(a.substr(9))
	for i in frames:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	print("captured ", img.get_size(), " renderer=", RenderingServer.get_current_rendering_method(),
		" driver=", RenderingServer.get_current_rendering_driver_name(),
		" adapter=", RenderingServer.get_video_adapter_name())
	if img.get_width() < 1280:
		var k := 1280 / img.get_width()
		img.resize(img.get_width() * k, img.get_height() * k, Image.INTERPOLATE_NEAREST)
	if out != "":
		img.save_png(out)
		print("saved ", out)
	get_tree().quit()
