# 🤝 Contributing to Protoolbag Mobile Core

Thank you for your interest in contributing! This document provides guidelines for contributing to the project.

## 📋 Code of Conduct

- Be respectful and constructive
- Welcome newcomers
- Focus on what is best for the community
- Show empathy towards other community members

## 🚀 Getting Started

### 1. Fork & Clone
```bash
# Fork the repository on GitHub
# Then clone your fork
git clone https://github.com/YOUR_USERNAME/protoolbag-mobile-core.git
cd protoolbag-mobile-core
```

### 2. Setup Development Environment
```bash
# Install dependencies
flutter pub get

# Run code generation
dart run build_runner build --delete-conflicting-outputs

# Run tests
flutter test
```

### 3. Create a Branch
```bash
git checkout -b feature/your-feature-name
# or
git checkout -b fix/your-bug-fix
```

## 💻 Development Workflow

### Making Changes

1. **Make your changes** in your feature branch
2. **Follow code style** guidelines (see below)
3. **Write tests** for new functionality
4. **Update documentation** if needed
5. **Test thoroughly** before committing

### Code Style

- Follow [Dart style guide](https://dart.dev/guides/language/effective-dart/style)
- Use `dartfmt` for formatting
- Run `flutter analyze` to check for issues
- Add documentation comments for public APIs
```dart
/// Validates email format.
///
/// Returns `null` if valid, error message if invalid.
///
/// Example:
/// ```dart
/// final error = Validators.email('test@example.com');
/// ```
String? email(String? value) { ... }
```

### Commit Messages

Follow [Conventional Commits](https://www.conventionalcommits.org/):
```
<type>(<scope>): <subject>

<body>

<footer>
```

**Types:**
- `feat`: New feature
- `fix`: Bug fix
- `docs`: Documentation only
- `style`: Formatting, no code change
- `refactor`: Code restructuring
- `test`: Adding tests
- `chore`: Build, dependencies

**Examples:**
```bash
git commit -m "feat(widgets): add AppIconButton component"
git commit -m "fix(auth): resolve token refresh issue"
git commit -m "docs: update component library examples"
```

### Testing
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/core/utils/validators_test.dart

# Run with coverage
flutter test --coverage
```

**Test Requirements:**
- All new features must have tests
- Bug fixes should include regression tests
- Maintain >80% code coverage
- Tests must pass before PR

## 📝 Pull Request Process

### 1. Before Submitting

- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Tests added/updated and passing
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Commits are clean and meaningful

### 2. Create Pull Request
```bash
# Push your branch
git push origin feature/your-feature-name

# Create PR on GitHub with:
# - Clear title
# - Description of changes
# - Link to related issues
# - Screenshots (if UI changes)
```

### 3. PR Template
```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Breaking change
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Widget tests added/updated
- [ ] Manual testing completed

## Checklist
- [ ] Code follows style guidelines
- [ ] Self-review completed
- [ ] Comments added for complex code
- [ ] Documentation updated
- [ ] No new warnings
- [ ] Tests pass locally

## Screenshots (if applicable)
[Add screenshots here]
```

### 4. Review Process

- Maintainers will review your PR
- Address review comments
- Keep PR updated with main branch
- Once approved, PR will be merged

## 🐛 Reporting Bugs

### Before Reporting

- Check existing issues
- Verify it's reproducible
- Gather relevant information

### Bug Report Template
```markdown
**Describe the bug**
Clear description of the bug

**To Reproduce**
Steps to reproduce:
1. Go to '...'
2. Click on '...'
3. See error

**Expected behavior**
What you expected to happen

**Screenshots**
If applicable

**Environment:**
 - Flutter version: [e.g. 3.19.0]
 - Core version: [e.g. 1.0.0]
 - Device: [e.g. iPhone 13]
 - OS: [e.g. iOS 17.0]

**Additional context**
Any other relevant information
```

## 💡 Feature Requests

### Before Requesting

- Check existing feature requests
- Ensure it aligns with project goals
- Consider if it belongs in core or project-specific

### Feature Request Template
```markdown
**Is your feature request related to a problem?**
Clear description of the problem

**Describe the solution you'd like**
Clear description of desired solution

**Describe alternatives you've considered**
Alternative solutions or features

**Additional context**
Any other context or screenshots

**Would you like to implement this?**
[ ] Yes, I can submit a PR
[ ] No, just suggesting
```

## 📚 Documentation

### When to Update Docs

- New features added
- API changes
- Breaking changes
- Configuration changes

### Documentation Files

- `README.md` - Overview and quick start
- `docs/API_REFERENCE.md` - API documentation
- `docs/COMPONENT_LIBRARY.md` - Widget catalog
- `docs/EXAMPLES.md` - Usage examples
- `CHANGELOG.md` - Version history

## 🏷️ Versioning

We use [Semantic Versioning](https://semver.org/):

- `MAJOR.MINOR.PATCH`
- MAJOR: Breaking changes
- MINOR: New features (backward compatible)
- PATCH: Bug fixes

## 📄 License

By contributing, you agree that your contributions will be licensed under the MIT License.

## ❓ Questions?

- Open an issue for discussion
- Contact: support@protoolbag.com
- Slack: #mobile-core channel

---

Thank you for contributing! 🎉