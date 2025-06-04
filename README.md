# xlstrip

**xlstrip** is a small and fast command-line utility for stripping a column from an Excel `.xlsx` spreadsheet.

The compiled binary is available in the `/dist` directory of this project.

---

## 🔧 Usage

```bash
xlstrip /full/path/to/spreadsheet.xlsx B
```

- The first parameter is the full path to the `.xlsx` file.
- The second parameter is the column letter to strip (e.g., `B` for the second column).

---

## 🛠️ Building from Source (Linux)

1. Install required system libraries:
   ```bash
   sudo apt install libxml2-dev libzip-dev
   ```

2. Install [Zig 0.15](https://ziglang.org/download/):

   Go to https://ziglang.org/download/ and download the current master
   ```bash
   tar -xf zig-linux-x86_64-0.15.0.tar.xz
   export PATH="$PWD/zig-linux-x86_64-0.15.0:$PATH"
   ```

3. Build the project:
   ```bash
   zig build
   ```

   This will create the binary in `zig-out/bin/`.

---


## 📄 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).
