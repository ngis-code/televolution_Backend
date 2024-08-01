# Download the code .zip file

# For downloading the code .zip file

This will download the code .zip file from the repository.
```bash
curl -L -O https://github.com/ngis-code/televolution_Backend/archive/refs/heads/main.zip
```

# For zipping all the files in the current directory
```bash
zip -r images.zip docker_image_builds
```

# Some custom script

```bash
curl -L -O https://github.com/ngis-code/televolution_Backend/archive/refs/heads/main.zip

unzip main.zip -d televolution_backend

cd televolution_backend

chmod +x docker_run.sh

./docker_run.sh download

./docker_run.sh load
```