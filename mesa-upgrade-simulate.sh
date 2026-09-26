echo '=== free space ==='
df -h /
echo '=== simulate upgrade (dry run) ==='
apk add --simulate --upgrade mesa mesa-dri-gallium mesa-egl mesa-gbm mesa-gl mesa-gles
