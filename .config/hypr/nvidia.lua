hl.env('LIBVA_DRIVER_NAME', 'nvidia')
hl.env('GBM_BACKEND', 'nvidia-drm')
hl.env('__GLX_VENDOR_LIBRARY_NAME', 'nvidia')
hl.env('__GL_VRR_ALLOWED', 1)
hl.env('WLR_DRM_NO_ATOMIC', 1)
hl.env('ELECTRON_OZONE_PLATFORM_HINT', 'auto')

-- nvidia libva driver config
hl.env('LIBVA_DRIVER_NAME', 'nvidia')
hl.env('NVD_BACKEND', 'nvidia')
hl.env('MOZ_DISABLE_RDD_SANDBOX', 1)
hl.env('EGL_PLATFORM', 'wayland')
