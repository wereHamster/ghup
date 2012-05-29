This is a script which can upload files to github from the commandline.

First you need to get a oauth token:

    curl -X POST -u <github user>:<github password> \
      -d '{"note":"file upload script","scopes":["repo"]}' \
      https://api.github.com/authorizations

Copy the token from the response and put it into your git config file:

     git config --global github.upload-script-token <the token from the response>


Now you can use this script.
