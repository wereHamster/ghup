This is a script which can upload files to github from the commandline.

### Installation

First you need to get a oauth token. The token must include either the `repo`
or `public_repo` scope.

    curl -X POST -u <github user>:<github password> \
      -d '{"note":"file upload script","scopes":["repo"]}' \
      https://api.github.com/authorizations

Copy the token from the response and put it into your git config file:

     git config --global github.upload-script-token <the token from the response>

### Usage

	github-upload.rb <file-name> [<repository>]

The `repository` parameter is optional. If one is not provided, if inside of a git repository, it will default to the remote named `origin`. If provided, the parameter should be in the format `<github user>/<repo>`.


### Example

	./github-upload.rb bin/sample-app.jar wereHamster/ghup

