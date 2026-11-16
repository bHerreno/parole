#!/usr/bin/env bash
# Environment installer for the "parole" project
# Creates Python and R environments, installs dependencies
# and installs Praat barren 6.4.60 for Linux.

set -e  # exit on error
cd "$(dirname "${BASH_SOURCE[0]}")"

########################################
# 0. Initial dependency checks
########################################
echo "📋 Checking system dependencies..."

missing_deps=()

check_dep() {
  if command -v "$1" &> /dev/null; then
    echo "  ✔ $1 found"
  else
    echo "  ❌ $1 NOT found"
    missing_deps+=("$1")
  fi
}

# Check required tools
for dep in ffmpeg ffprobe Rscript; do
  check_dep "$dep"
done

# Always install the pinned local version, even if system Praat is available.
bash scripts/install_praat.sh

########################################
# 2. Confirm whether to continue if dependencies are missing
########################################
if [ ${#missing_deps[@]} -gt 0 ]; then
  echo ""
  echo "⚠️ The following system dependencies are missing:"
  printf '   - %s\n' "${missing_deps[@]}"
  echo ""
  read -p "Continue installing the Python and R environments anyway? [y/N]: " cont
  if [[ "$cont" != "y" && "$cont" != "Y" ]]; then
    echo "🛑 Installation cancelled."
    exit 1
  fi
fi

echo ""
echo "✅ Continuing with environment installation..."
echo ""

########################################
# 3. Reinstall / create the Python environment
########################################
REINSTALL_PY=false
if [ -d env/pyenv ]; then
  echo "⚠️ An existing Python environment was found at 'env/pyenv'."
  read -p "Reinstall (delete and recreate) the Python environment? [y/N]: " ans_py
  if [[ "$ans_py" == "y" || "$ans_py" == "Y" ]]; then
    REINSTALL_PY=true
    echo "🗑 Deleting the existing Python environment..."
    rm -rf env/pyenv
  fi
fi

if [ ! -f requirements_python.txt ]; then
  echo "❌ Could not find 'requirements_python.txt'"
  read -p "Continue without installing Python dependencies? [y/N]: " py_skip
  if [[ "$py_skip" != "y" && "$py_skip" != "Y" ]]; then
    echo "🛑 Installation cancelled."
    exit 1
  fi
else
  # If REINSTALL_PY = true or env/pyenv did not exist
  if [ "$REINSTALL_PY" = true ] || [ ! -d env/pyenv ]; then
    echo "🔧 Creating the Python environment at env/pyenv..."
    python3 -m venv env/pyenv
    source env/pyenv/bin/activate
    pip install --upgrade pip

    echo "📦 Installing dependencies from requirements_python.txt..."
    pip install -r requirements_python.txt

    deactivate
    echo "✅ Python environment created and installed successfully."
  else
    echo "✅ Keeping the existing Python environment at env/pyenv"
    echo "   (To reinstall it, run this script again and choose 'y')"
  fi
fi

########################################
# 4. Reinstall / create the R library
########################################
REINSTALL_R=false
if [ -d env/Rlibs ]; then
  echo "⚠️ An existing R library was found at 'env/Rlibs'."
  read -p "Reinstall (delete and recreate) the R library? [y/N]: " ans_r
  if [[ "$ans_r" == "y" || "$ans_r" == "Y" ]]; then
    REINSTALL_R=true
    echo "🗑 Deleting the existing R library..."
    rm -rf env/Rlibs
  fi
fi

# Remove .Renviron if it exists and the R library is being reinstalled
if [ -f .Renviron ] && [ "$REINSTALL_R" = true ]; then
  echo "🗑 Deleting the existing .Renviron..."
  rm -f .Renviron
fi

if [ "$REINSTALL_R" = true ] || [ ! -d env/Rlibs ]; then
  echo ""
  echo "📁 Creating the R library directory at env/Rlibs..."
  mkdir -p env/Rlibs

  # Create a local .Renviron
  echo "R_LIBS_USER=${PWD}/env/Rlibs" > .Renviron
  echo "✅ Created .Renviron with R_LIBS_USER=${PWD}/env/Rlibs"

  echo "📦 Installing required R packages..."
  Rscript -e 'install.packages(c("arrow", "data.table", "tidyverse"), repos="https://cloud.r-project.org", lib="env/Rlibs")'

  echo "✅ R packages installed successfully in env/Rlibs"
else
  echo "✅ Keeping the existing R library at env/Rlibs"
  echo "   (To reinstall them, run this script again and choose 'y')"
fi

echo ""
echo "🎉 Installation complete. Ready to use ./scripts/parole.sh"

