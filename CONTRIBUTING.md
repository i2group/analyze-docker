# Contributing Guidelines

Thank you for considering to contribute to the Analyze Docker repository! Before you
get started, we recommend taking a look at the guidelines below:

- [Have a Question?](#have-a-question)
- [Issues and Bugs](#discover-a-bug)
- [Feature Requests](#missing-feature)
- [Contributing](#contributing)
  - [Submission Guidelines](#submission-guidelines)
  - [Release Process](#how-to-release)

## Have a Question?

Have a question about Analyze Containers or the Analyze Docker repositories?

### I have a general question about the repositories/tools

You can always open a new [issue](https://github.com/i2group/analyze-docker/issues) on the
repository on GitHub and our project team will be reviewed and investigated.

Otherwise, contact i2's general support by filing a ticket here:
[Submit a request](https://i2group.com/support-request).

## Discover a Bug?

Find an issue or bug?

You can help us resolve the issue by
[submitting an issue](https://github.com/i2group/analyze-docker/issues/new/choose)
on our GitHub repository.

Up for a challenge? If you think you can fix the issue, consider sending in a
[Pull Request](#submission-guidelines).

## Missing Feature?

Is anything missing?

You can request a new feature by
[submitting an issue](https://github.com/i2group/analyze-docker/issues/new/choose)
to our GitHub repository, utilizing the `Feature Request` template.

If you would like to instead contribute a pull request, please follow the
[Submission Guidelines](#submission-guidelines)

## Contributing

Thank you for contributing to Analyze Docker!

Before submitting any new Issue or Pull Request, search our repository for any
existing or previous related submissions.

- [Search Pull Requests](https://github.com/i2group/analyze-docker/pulls?q=)
- [Search Issues](https://github.com/i2group/analyze-docker/issues?q=)

### Submission Guidelines

#### Submitting a Pull Request

After searching for potentially existing pull requests or issues in progress, if
none are found, please open a new issue describing your intended changes and
stating your intention to work on the issue.

Creating issues helps us plan our next release and prevents folks from
duplicating work.

After the issue has been created, follow these steps to create a Pull Request.

1. Set up the project prerequisites. To learn more, read [Prerequisites](DEVELOPING.md#prerequisites).
1. Fork the
   [i2group/analyze-docker](https://github.com/i2group/analyze-docker)
   repo.
1. Clone your newly forked repository to your local machine.
1. Create a new branch for your changes: `git checkout -b <branch_name> main`.

   Ensure to follow branch naming convention:

   - Prefix with `pr/`
   - Followed by the issue number
   - Optionally add a quick summary

   Like `pr/<issue_number>[-<summary>]`. E.g. `pr/1-fix-solr-start`.

1. Implement your change with appropriate test coverage. To learn more read [Making a change](DEVELOPING.md#making-a-change).
1. Push all changes back to GitHub `git push origin <branch_name>`
1. In GitHub, send a Pull Request to `analyze-docker:main`

Thank you for your contribution!

##### After Your PR Has Been Merged

After your pull request is merged, the project team will decide to release when ready.
This is usually aimed to be done weekly.

## Legal

The project is licensed under [MIT license](./LICENSE).

Any contributions submitted will be subject to the same license as the rest of the code. No new restrictions/conditions are permitted.

As a contributor, you MUST have the legal right to grant permission for your contribution to be used under these conditions.
