"""Give the bundled Windows executable the identity used by the installer."""
from pathlib import Path
import sys


def prepare(folder):
    folder = Path(folder)
    source = folder / "rustdesk.exe"
    target = folder / "KowsarDesk.exe"
    # Validate before modifying the payload; never overwrite another build.
    for required in (source, folder / "librustdesk.dll", folder / "flutter_windows.dll"):
        if not required.is_file():
            raise FileNotFoundError(f"Missing Windows payload: {required}")
    if target.exists():
        raise FileExistsError(f"Branded executable already exists: {target}")
    source.rename(target)
    return target


if __name__ == "__main__":
    print(prepare(sys.argv[1]))
