# Contributing to Sonolyth

First off, thanks for taking the time to contribute! ❤️

All types of contributions are encouraged and valued. See the [Table of Contents](#table-of-contents) for different ways to help and details about how this project handles them. Please make sure to read the relevant section before making your contribution. It will make it a lot easier for the maintainer and smooth out the experience for all involved. 🎉

> And if you like the project but just don't have time to contribute, that's fine. There are other easy ways to support the project and show your appreciation, which would also be very welcome:
>
> - Star the project
> - Refer to this project in your project's readme
> - Mention the project to friends/colleagues

## Table of Contents

- [Contributing to Sonolyth](#contributing-to-sonolyth)
  - [Table of Contents](#table-of-contents)
  - [Code of Conduct](#code-of-conduct)
  - [I Have a Question](#i-have-a-question)
  - [I Want To Contribute](#i-want-to-contribute)
    - [Reporting Bugs](#reporting-bugs)
      - [Before Submitting a Bug Report](#before-submitting-a-bug-report)
      - [How Do I Submit a Good Bug Report?](#how-do-i-submit-a-good-bug-report)
    - [Suggesting Enhancements](#suggesting-enhancements)
      - [Before Submitting an Enhancement](#before-submitting-an-enhancement)
      - [How Do I Submit a Good Enhancement Suggestion?](#how-do-i-submit-a-good-enhancement-suggestion)
    - [Your First Code Contribution](#your-first-code-contribution)
    - [Submit Translations](#submit-translations)

## Code of Conduct

This project and everyone participating in it is governed by the
[Sonolyth Code of Conduct](https://github.com/ezrasong/sonolyth/blob/master/CODE_OF_CONDUCT.md).
By participating, you are expected to uphold this code. Please report unacceptable behavior
to ezrasong410@gmail.com.

## I Have a Question

> If you want to ask a question, we assume that you have read the available [Documentation](https://github.com/ezrasong/sonolyth#readme).

Before you ask a question, it is best to search for existing [Issues](https://github.com/ezrasong/sonolyth/issues) that might help you. In case you have found a suitable issue and still need clarification, you can write your question in this issue. It is also advisable to search the internet for answers first.

If you then still feel the need to ask a question and need clarification, we recommend the following:

- Open a [Discussion](https://github.com/ezrasong/sonolyth/discussions/new) with the question label.
- Provide as much context as you can about what you're running into.
- Provide project and platform versions (flutter, dart, pub, etc.), depending on what seems relevant.

## I Want To Contribute

> ### Legal Notice
>
> When contributing to this project, you must agree that you have authored 100% of the content, that you have the necessary rights to the content and that the content you contribute may be provided under the project license.

### Reporting Bugs

#### Before Submitting a Bug Report

A good bug report shouldn't leave others needing to chase you up for more information. Therefore, we ask you to investigate carefully, collect information and describe the issue in detail in your report. Please complete the following steps in advance to help us fix any potential bug as fast as possible.

- Make sure that you are using the latest version.
- Determine if your bug is really a bug and not an error on your side e.g. using incompatible environment components/versions (make sure that you have read the [documentation](https://github.com/ezrasong/sonolyth#readme); if you are looking for support, you might want to check [this section](#i-have-a-question)).
- To see if other users have experienced (and potentially already solved) the same issue you are having, check if there is not already a bug report existing for your bug or error in the [bug tracker](https://github.com/ezrasong/sonolyth/issues?q=label%3Abug).
- Also make sure to search the internet (including Stack Overflow) to see if users outside of the GitHub community have discussed the issue.
- Collect information about the bug:
- Stack trace (Traceback)
- OS, Platform and Version (Windows, Linux, macOS, x86, ARM)
- Version of the interpreter, compiler, SDK, runtime environment, package manager, depending on what seems relevant.
- Possibly your input and the output
- Can you reliably reproduce the issue? And can you also reproduce it with older versions?

#### How Do I Submit a Good Bug Report?

> You must never report security related issues, vulnerabilities or bugs including sensitive information to the issue tracker, or elsewhere in public. Instead, sensitive bugs must be sent by email to ezrasong410@gmail.com.

We use GitHub issues to track bugs and errors. If you run into an issue with the project:

- Open an [Issue](https://github.com/ezrasong/sonolyth/issues/new). (Since we can't be sure at this point whether it is a bug or not, we ask you not to talk about a bug yet and not to label the issue.)
- Explain the behavior you would expect and the actual behavior.
- Please provide as much context as possible and describe the _reproduction steps_ that someone else can follow to recreate the issue on their own. This usually includes your code. For good bug reports you should isolate the problem and create a reduced test case.
- Provide the information you collected in the previous section.

Once it's filed:

- The project team will label the issue accordingly.
- A team member will try to reproduce the issue with your provided steps. If there are no reproduction steps or no obvious way to reproduce the issue, the team will ask you for those steps and mark the issue as `needs-repro`. Bugs with the `needs-repro` tag will not be addressed until they are reproduced.
- If the team is able to reproduce the issue, it will be marked `needs-fix`, as well as possibly other tags (such as `critical`), and the issue will be left to be [implemented by someone](#your-first-code-contribution).

### Suggesting Enhancements

This section guides you through submitting an enhancement suggestion for Sonolyth, **including completely new features and minor improvements to existing functionality**. Following these guidelines will help maintainers and the community understand your suggestion and find related suggestions.

#### Before Submitting an Enhancement

- Make sure that you are using the latest version.
- Read the [documentation](https://github.com/ezrasong/sonolyth#readme) carefully and find out if the functionality is already covered, maybe by an individual configuration.
- Perform a [search](https://github.com/ezrasong/sonolyth/issues) to see if the enhancement has already been suggested. If it has, add a comment to the existing issue instead of opening a new one.
- Find out whether your idea fits with the scope and aims of the project. It's up to you to make a strong case to convince the project's developers of the merits of this feature.

#### How Do I Submit a Good Enhancement Suggestion?

Enhancement suggestions are tracked as [GitHub issues](https://github.com/ezrasong/sonolyth/issues).

- Use a **clear and descriptive title** for the issue to identify the suggestion.
- Provide a **step-by-step description of the suggested enhancement** in as many details as possible.
- **Describe the current behavior** and **explain which behavior you expected to see instead** and why. At this point you can also tell which alternatives do not work for you.
- You may want to **include screenshots and animated GIFs** which help you demonstrate the steps or point out the part which the suggestion is related to.
- **Explain why this enhancement would be useful** to most Sonolyth users.

### Your First Code Contribution

Do the following:

- Install [Flutter](https://docs.flutter.dev/get-started/install) (the SDK in `.tooling/` is what this repo is built with) plus the Android SDK and a connected device or emulator.
- Clone the repo. The Spotify plugin is vendored in-tree as git subtrees — no submodule init needed; see [MONOREPO.md](MONOREPO.md).
- Create a `.env` in the root of the project following the `.env.example` template.
- Bootstrap the project:
  ```bash
  flutter pub get && dart run build_runner build --delete-conflicting-outputs
  ```
- Run Sonolyth on a connected Android device or emulator:
  ```bash
  flutter run --flavor stable -d <android-device-id>
  ```

Do debugging/testing/build, then open a PR against `master` and it'll be reviewed.

### Submit Translations

Make sure you're familiar with [Flutter localization](https://docs.flutter.dev/ui/accessibility-and-localization/internationalization). Then you can start translating the app:

- Do all the steps in [Your First Code Contribution](#your-first-code-contribution).
- Make sure the application starts in debug mode.
- In `lib/l10n/app_<2-letter language code>.arb` (create it if it doesn't exist) add the necessary translations.
  > (Use `lib/l10n/app_en.arb` for reference.)
- If you're adding missing translations, check `untranslated_messages.json` to see which messages are missing in your locale.
- If you added an entirely new locale:
  - Add `const Locale('<2-letter language code>', '<2-letter ISO country code>')` in `lib/l10n/l10n.dart`'s `static final all = [...]` list.
  - Uncomment the map entry for your locale in `lib/collections/language_codes.dart`'s `static final Map isoLangs = {`.
- Restart (hot restart) the app in debug mode, go to "Settings" → "Language", and check that your locale shows up and renders correctly.
- Commit the changes and open a PR against `master`.
