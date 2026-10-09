# Microsoft chat plugin for Redmine

[![tests](https://github.com/yukkes/redmine_microsoftteams/actions/workflows/tests.yml/badge.svg)](https://github.com/yukkes/redmine_microsoftteams/actions/workflows/tests.yml)
[![Redmine](https://img.shields.io/badge/Redmine-5.0%20%7C%205.1%20%7C%206.0%20%7C%206.1%20%7C%207.0-B32024?logo=redmine)](https://www.redmine.org/)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Code style: RuboCop](https://img.shields.io/badge/code_style-rubocop-brightgreen.svg)](https://github.com/rubocop/rubocop)

This plugin posts updates to issues in your Redmine installation to a Microsoft Teams channel.

This code is based on the [redmine-slack](https://github.com/sciyoshi/redmine-slack) plugin.

## Requirements

* Redmine 5.0 or later (tested with 5.0, 5.1, 6.0, 6.1 and 7.0)

## Installation

From your Redmine plugins directory, clone this repository as `redmine_microsoftteams`
```
git clone https://github.com/wellbia/redmine_microsoftteams.git redmine_microsoftteams
```

You will also need the `httpclient` dependency, which can be installed by running
```
bundle install
```
from the plugin directory.

Restart Redmine, and you should see the plugin show up in the Plugins page. Under the configuration options, set the Teams URL to the url for Microsoft Teams Incoming Webhook in your Microsoft Teams channel.

Run plugin migrations to enable the Microsoft Teams project module for existing projects and add it to Redmine's default project modules:
```
bundle exec rake redmine:plugins:migrate RAILS_ENV=production
```

## Customized Routing

You can also route messages to different channels on a per-project basis. To do this, create a project custom field (Administration > Custom fields > Project) named `Teams URL`. If no custom channel is defined for a project, the parent project will be checked(or the default will be used). To prevent all notifications from being sent for a project, set the custom channel to `-`.

Microsoft Teams notifications can be enabled or disabled per project from Project settings > Modules. The `Microsoft Teams webhook` module is enabled by default; uncheck it to disable all Teams notifications for that project.

## Difference with redmine-slack Plugin

In this plugin, somethings is not beautiful to see(ex. newline, missing html entity in codeblock). We will fix it if find a better way.

## Development

After checking out the repository, run

```
$ bin/build
```

to build the Docker container used to run the test suite. Pass
`--build-arg REDMINE_VERSION=5.0` to test against another Redmine
version (5.0, 5.1, 6.0, 6.1 or 7.0). Then run

```
$ bin/test
```

to run the tests. Run `rubocop` and `brakeman` to check the code style
and security.
