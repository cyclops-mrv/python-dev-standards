import re
import sys
from pathlib import Path

import yaml
from prefect.flows import load_flow_from_entrypoint


def main() -> None:
    """Print flow name and deployment base name pairs from prefect.yaml."""
    data = yaml.safe_load(Path(sys.argv[1]).read_text())
    for dep in data.get("deployments", []):
        flow = load_flow_from_entrypoint(dep["entrypoint"].strip())
        base = re.sub(r"\{\{.*?\}\}", "", dep["name"]).strip()
        sys.stdout.write(f"{flow.name}\t{base}\n")


if __name__ == "__main__":
    main()
