Contributing to PostgreSQL CDC Multi-Cloud Pipeline
Thank you for considering contributing to this project! Here are some guidelines to help you get started.
🐛 Reporting Issues
If you find a bug or have a feature request:

Check if the issue already exists in the Issues section
If not, create a new issue with:

Clear title and description
Steps to reproduce (for bugs)
Expected vs actual behavior
Environment details (cloud provider, versions, etc.)
Relevant logs or error messages



🔧 Development Setup
Prerequisites

Java 17+
Maven 3.9+
Docker
Terraform 1.5+
Git

Local Development
bash# Clone the repository
git clone https://github.com/YOUR_USERNAME/postgres-cdc-multicloud.git
cd postgres-cdc-multicloud

# Build the project
mvn clean package

# Run tests
mvn test

# Build Docker image locally
docker build -t cdc-pipeline:dev .
Running Locally
You can test the CDC pipeline locally using Docker Compose (coming soon) or by running against a local PostgreSQL instance.
📝 Making Changes
Branch Naming Convention

feature/description - New features
fix/description - Bug fixes
docs/description - Documentation updates
chore/description - Maintenance tasks

Commit Message Format
Follow Conventional Commits:
<type>(<scope>): <subject>

<body>

<footer>
Types:

feat: New feature
fix: Bug fix
docs: Documentation changes
style: Code style changes (formatting, etc.)
refactor: Code refactoring
test: Adding/updating tests
chore: Maintenance tasks

Example:
feat(storage): add retry logic for Azure blob uploads

Implements exponential backoff retry mechanism for transient
Azure Storage failures. Improves reliability under high load.

Closes #123
Code Style

Java: Follow Google Java Style Guide
Terraform: Use terraform fmt before committing
Maximum line length: 100 characters
Use meaningful variable and function names

Testing

Write unit tests for new Java code
Update integration tests if changing core functionality
Ensure all tests pass before submitting PR: mvn test
Add Terraform validation tests for infrastructure changes

🔄 Pull Request Process

Fork the repository and create your branch from main
Make your changes following the guidelines above
Update documentation if needed:

README.md for user-facing changes
Code comments for complex logic
Update CHANGELOG.md (if exists)


Test thoroughly:

bash   mvn clean test
   docker build -t cdc-pipeline:test .
   terraform validate (for each cloud)

Submit pull request:

Fill in the PR template
Link related issues
Provide clear description of changes
Add screenshots/logs if applicable


Code Review:

Address reviewer comments
Keep PR updated with main branch
Be responsive and collaborative


Merge:

PRs will be merged by maintainers after approval
Squash commits may be used for cleaner history



🏗️ Architecture Decisions
For significant architectural changes:

Open an issue first to discuss the approach
Provide rationale and alternatives considered
Get consensus from maintainers before implementing
Update architecture documentation

📚 Documentation
Documentation improvements are always welcome!

README.md: Getting started, quick setup
docs/ARCHITECTURE.md: System design, component interactions
docs/DEPLOYMENT.md: Detailed deployment guide
docs/TROUBLESHOOTING.md: Common issues and solutions
Code comments: Complex logic, non-obvious decisions

🧪 Adding New Cloud Providers
To add support for a new cloud provider:

Implement StorageSink interface in src/main/java/com/cdc/storage/
Update StorageSinkFactory.java to include new provider
Add Terraform configuration in terraform/your-cloud/
Update Makefile with new deployment targets
Add documentation and examples
Submit PR with tests

🐞 Debugging
Enabling Debug Logs
bash# In your container environment
export JAVA_OPTS="-Dlogback.configurationFile=logback-debug.xml"
Common Issues
See docs/TROUBLESHOOTING.md for solutions to common problems.
📜 License
By contributing, you agree that your contributions will be licensed under the MIT License.
🙏 Thank You!
Your contributions make this project better for everyone. Thank you for taking the time to contribute!