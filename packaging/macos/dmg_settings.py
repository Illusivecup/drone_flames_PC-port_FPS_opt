import os

PKG_DIR = os.path.dirname(os.path.abspath(__file__))

# Volume Name
volume_name = "DroneFlames"
format = "UDZO"

# Background & Volume Icon
background = os.path.join(PKG_DIR, "background.tiff")
icon = os.path.join(PKG_DIR, "VolumeIcon.icns")

# Symlinks
symlinks = {
    "Applications": "/Applications"
}

# Window Coordinates and Dimensions
window_rect = ((200, 120), (600, 400))
default_view = "icon-view"

# Icon View Settings
icon_size = 96
text_size = 12

# Icon Positions: DroneFlames on the left, Applications on the right
icon_locations = {
    "DroneFlames.app": (150, 195),
    "Applications": (450, 195)
}

# Window Chrome
hide_extensions = ["DroneFlames.app"]
show_status_bar = False
show_tab_view = False
show_toolbar = False
show_pathbar = False
show_sidebar = False
