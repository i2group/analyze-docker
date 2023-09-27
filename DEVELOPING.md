# Developing

The following describes the structure of this repository and how to develop the images contained in it.

## Prerequisites

### Windows Subsystem for Linux (WSL)

If you are on **Windows**, you must use WSL 2 as the backend for Docker and to run the shell scripts in this repository.

1. In an administrator Command Prompt, run the following command:

    ```cmd
    wsl --install
    ```

1. Restart your machine to complete the installation.
1. After you restart, open the distribution. Press **Start -> wsl**
1. You will be asked to create a User Name and Password for your Linux distribution.  
    For more information, see [Set up your Linux username and password](https://docs.microsoft.com/en-gb/windows/wsl/setup/environment#set-up-your-linux-username-and-password).
1. Create a mapped network drive in Windows for WSL.
    1. In a command prompt, run the following command to list your WSL distributions.

        ```sh
        wsl --list
        ```

    1. Run the following command to map your WSL distribution to the Z: drive. Use the name of your default WSL distribution as displayed after running the previous command. You can use any drive letter.

        ```sh
        net use Z: \\wsl$\Ubuntu
        ```

    You can now access the WSL filesystem from Windows

### Docker

1. Install Docker CE for your operating system. For more information about installing Docker CE, see <https://docs.docker.com/engine/installation/>.

    * *Mac OS* : [Install Docker CE](https://docs.docker.com/docker-for-mac/install/)
    * *Windows* :  
        1. [Install Docker CE](https://docs.docker.com/docker-for-windows/install/)
        1. [Set up Docker on WSL 2](https://docs.docker.com/docker-for-windows/wsl/)

1. After you install Docker, allocate at least 5GB of memory to Docker to run the containers in the example deployment.

    On Windows, Docker is automatically allocated 8GB or 50% of available memory whichever is less.

    For more information about modifying the resources allocated to Docker, see:

    * [Docker Desktop for Windows](https://docs.docker.com/desktop/settings/windows/#resources)
    * [Docker Desktop for Mac](https://docs.docker.com/docker-for-mac/#resources)

### Visual Studio Code (DevContainer)

To develop, we make use of a VSCode Dev Container which is already set up with the project dependencies.

1. If you haven't already, download and install [VS Code](https://code.visualstudio.com/download)

   * On Windows, when prompted to Select Additional Tasks during installation select the **Add to PATH** option so you can easily open a folder in WSL using the code command.
   * On MacOS, after you install VS Code to your PATH. For more information, see [Launching from the command line](https://code.visualstudio.com/docs/setup/mac#_launching-from-the-command-line).

1. Install the [Dev Containers extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-containers)

1. On Windows, use the following instructions to open the folder in WSL.

   1. Install the [WSL extension](https://marketplace.visualstudio.com/items?itemName=ms-vscode-remote.remote-wsl)
   1. Press **F1** and type `WSL: New WSL Window` and select it.

1. Press **F1** (or **Cmd+Shift+P** in MacOS) and type `Dev Containers: Open Folder in Container` and select it. In the file explorer, navigate to your `analyze-docker` directory. For example: `/home/<user-name>/analyze-docker`.  
   If you are prompted, click **Trust Folder & Continue**.
1. After the dev container starts, if you are prompted, click **Install** in the pop-up that is displayed that prompts you to install the recommended VS Code extensions.

For more information about VS Code dev containers, see [Developing in a container](https://code.visualstudio.com/docs/remote/containers).

## Project Structure

The `images` directory contains a folder per each supported image and inside each there is a folder per supported version with the Dockerfile and any other required scripts to build the image.

E.g.

```text
-- images
  |-- <image_name_1>
    |-- <version_1>
    |-- <version_2>
  |-- <image_name_2>
    |-- <version_1>
    |-- <version_2>
    |-- <version_3>
```

### Making a change

The top scripts used in the project are `build.sh` and `test.sh`.
During the rest of this document we will provide examples of how to make changes
to the Solr image and run these commands.
Use the `-h` flag for more information on how to run them.

To make a change to Solr image in version 8.11, follow the steps:

1. Go to `images/solr/8.11`
1. Make the required changes in your editor.
  If you added a new dependency ensure to add it to the test in `test.sh`.
1. Run `./build.sh -i solr -v 8.11` to build your image locally.
  At the end you should see the image `i2group/i2eng-solr:8.11` created.
1. Run `./test.sh i2group/i2eng-solr:8.11` to ensure it starts and is correctly configured.
1. Submit a Pull Request
