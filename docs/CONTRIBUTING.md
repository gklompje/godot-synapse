# 🤝 Contributing to Synapse
First off, thank you for considering contributing to Synapse! This project is currently in
**Alpha**, and community feedback and contributions are what will help it reach a stable 1.0.

Whether you are fixing a bug, improving documentation, or suggesting a new feature, we are happy to
have you here.

## 🚀 How to Get Started
1. **Check the Roadmap:** Take a look at our [ROADMAP.md](./ROADMAP.md) and
[GitHub Issues](https://github.com/gklompje/godot-synapse/issues) to see what we’re currently
focused on.
2. **Open an Issue:** If you find a bug or have a new idea, please open an issue first so we can
discuss it before you spend significant time on code.
3. **Fork & Branch:** Create a fork of the repo and a new branch for your feature or fix (e.g.,
`feature/runtime-debugger`).

## 🛠️ Development Guidelines

### ⚠️ GDScript Standards
To ensure Synapse remains robust, this project is developed with most **GDScript warnings set to
errors**.
* **The Environment:** Please check out the whole project and use the included `project.godot` file.
This ensures your editor settings match the project's strict warning levels.
* **Code Style:** We aim for clean, readable GDScript that favors composition over inheritance.

### 🧪 Testing & Verification
We do not yet have an automated unit testing suite. Until one is implemented, please perform the
following manual checks before submitting a Pull Request:
1. **The Playground:** Test any changed functionality or new UI logic inside the `/demos/test`
project.
2. **Regression Check:** Run through all existing **Demos** (especially *Cletus Loves Apples*) to
ensure your changes didn't break existing behavior.

### 📝 Documentation
If you’re adding a new feature or changing an existing API, please update the relevant documentation
in `/docs` or the internal README files. We want Synapse to be as approachable as possible.

New `/demos` are a great way to showcase any new functionality, concepts, or patterns.

## ❤️ Code of Conduct
The goal is to build a helpful tool for the Godot community. We value a welcoming, inclusive, and
kind environment. Please be respectful and constructive in your communication.

---

### ❓ Questions?
If you're unsure about where to start or how a specific part of the graph logic works, feel free to
[open a discussion](https://github.com/gklompje/godot-synapse/discussions) or reach out via
[an Issue](https://github.com/gklompje/godot-synapse/issues)!
