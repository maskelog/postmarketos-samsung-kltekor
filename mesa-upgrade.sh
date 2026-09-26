apk add --upgrade mesa mesa-dri-gallium mesa-egl mesa-gbm mesa-gl mesa-gles
echo '=== result ==='
apk info -v | grep -E '^mesa'
df -h /
