# Unknown Stack Fixture

This fixture represents a project with an unrecognizable technology stack.
It has no standard package manager files (package.json, Cargo.toml, pom.xml, etc.)
and uses a custom build configuration format.

harness-init should detect this as an unknown stack and operate in degraded mode
for stack-specific features while still providing core navigation and governance.
