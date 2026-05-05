# Spine Background Backup

The main scene no longer uses these Spine background assets directly.

Current main-screen motion is driven by layered Taxi PNG assets under:

```text
res://assets/Taxi/
```

The previous Spine background controller is retained at:

```text
res://scripts/spine_background_controller.gd
```

Keep these files as backup/reference for rollback, validation probes, or future
content reuse.
