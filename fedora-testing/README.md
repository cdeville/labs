# Test install & build scripts for standard Fedora images  

# Build the image
docker build -t fedora43-systemd .

# Run with systemd (requires privileged mode and cgroup mount)
docker run -d \
  --name fedora-test \
  --privileged \
  -v /sys/fs/cgroup:/sys/fs/cgroup:rw \
  --cgroupns=host \
  fedora43-systemd

# Enter as root
docker exec -it fedora-test /bin/bash

# Enter as testuser
docker exec -it -u testuser fedora-test /bin/bash

# Stop & remove the container
docker stop fedora-test && docker rm fedora-test

