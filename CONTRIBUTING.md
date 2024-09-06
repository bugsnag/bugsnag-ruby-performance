## How to contribute

We are glad you're here! First-time and returning contributors are welcome to add bug fixes and new integrations. If you are unsure about the direction of an enhancement or if it would be generally useful, feel free to open an issue or a work-in-progress pull request and ask for input.

Thank you!

### Getting started

* [Fork](https://help.github.com/articles/fork-a-repo) the [library on github](https://github.com/bugsnag/bugsnag-ruby-performance)
* Commit and push until you are happy with your contribution

### Polish

* Install the test dependencies

    ```
    bundle install
    ```

* Run the tests and make sure they all pass

    ```
    bundle exec rspec
    ```
    
* Further information on installing and running the tests can be found in [the testing guide](./TESTING.md)

### Document

* Write API docs for your contributions using [YARD](https://yardoc.org/)
* Generate the API documentation locally
    ```
    bin/rake yard
    ```
* Review your changes by opening `doc/index.html`

### Ship it!

* [Make a pull request](https://help.github.com/articles/using-pull-requests)

## How to release

If you're a member of the core team, follow these instructions for releasing bugsnag-ruby-performance.

### First time setup

* Create a Rubygems account
* Get someone to add you as contributor on bugsnag-ruby-performance in Rubygems

### Every time

* Create a new release branch named in the format `release/v1.x.x`
* Update the version number in [`lib/bugsnag_performance/version.rb`](./lib/bugsnag_performance/version.rb)
* Update [`CHANGELOG.md`](./CHANGELOG.md) with any changes
* Open a pull request into `main` and get it approved
* Merge the pull request using the message "Release v1.x.x"
* Make a GitHub release
* Release to rubygems:

    ```
    gem build bugsnag-performance.gemspec
    gem push bugsnag_performance-1.x.x.gem
    ```

* Update the version running in the bugsnag-website project

### Update docs.bugsnag.com

Update the setup guides for Ruby (and its frameworks) with any new content.
