"""Compare the GUI worker with the release CLI on the same mixed-panel acquisition.

Usage: python worker-parity.py STANDALONE_WORKER GUI_WORKER
"""

import base64
import csv
import math
from pathlib import Path
import shutil
import struct
import subprocess
import sys
import tempfile


def array(values, kind):
    payload = base64.b64encode(struct.pack(f"<{len(values)}f", *values)).decode()
    return (f'<binaryDataArray><cvParam accession="MS:1000521" name="32-bit float"/>'
            f'<cvParam accession="MS:1000576" name="no compression"/>'
            f'<cvParam accession="{kind}"/><binary>{payload}</binary></binaryDataArray>')


def trace(index, precursor, sample):
    times = [1 + i / 200 for i in range(201)]
    values = [20 + i % 3 + (800 + 50 * sample) * math.exp(-((t - 1.5) / 0.045)**2)
              for i, t in enumerate(times)]
    return (f'<chromatogram index="{index}"><cvParam accession="MS:1000130"/>'
            f'<precursor><isolationWindow><cvParam accession="MS:1000827" value="{precursor}"/>'
            '</isolationWindow></precursor><product><isolationWindow>'
            '<cvParam accession="MS:1000827" value="184"/></isolationWindow></product>'
            '<binaryDataArrayList>' + array(times, "MS:1000595") + array(values, "MS:1000515")
            + '</binaryDataArrayList></chromatogram>')


def inputs(project):
    (project / "mzML").mkdir(parents=True)
    (project / "param.txt").write_text('num_threads = 2\nRT_shift = [0, 0]\nfill_RT = true\n')
    (project / "run_order.csv").write_text("file_name,sample_type,reference,learn\n"
                                           "first.mzML,SPL,y,y\nmiddle.mzML,SPL,,y\nlast.mzML,SPL,,\n")
    (project / "feature_list.csv").write_text(
        "Feature_ID,Transition_Name,ISTD_Feature_ID,Precursor_Ion,Product_Ion,RT,start_RT,end_RT,peak_width,baseline\n"
        "All,All,,500,184,1.5,1.4,1.6,,default\n"
        "Partial,Partial,All,510,184,1.5,1.4,1.6,,v2v\n"
        "NoRef,NoRef,All,520,184,1.5,1.4,1.6,,v_drop\n")
    for i, (name, masses) in enumerate([("first", [500, 510]), ("middle", [500, 520]),
                                         ("last", [500, 510, 520])]):
        traces = "".join(trace(j, mass, i) for j, mass in enumerate(masses))
        xml = (f'<mzML><run startTimeStamp="2026-01-0{i+1}T12:00:00Z">'
               f'<chromatogramList>{traces}</chromatogramList></run></mzML>')
        if i == 1:
            xml = f"<indexedmzML>{xml}</indexedmzML>"
        (project / "mzML" / f"{name}.mzML").write_text(xml)


def run(exe, step):
    subprocess.run([str(exe), str(step)], cwd=exe.parent, check=True, timeout=90)


def verify(root, cli, gui):
    projects = [root / "standalone", root / "GUI"]
    workers = []
    for project, binary in zip(projects, [cli, gui]):
        inputs(project)
        executable = Path(shutil.copy2(binary, project))
        workers.append(executable)
        run(executable, 1)
        run(executable, 2)
    for method in ("flank", "rms", "robust", "p2p"):
        for project, worker in zip(projects, workers):
            (project / "param.txt").write_text(f'num_threads = 2\nsn_noise = "{method}"\n')
            run(worker, 3)
        for name in ["RT_matrix.csv", "long.csv", "quant_raw.csv", "missing_compounds.txt", "missing_details.txt"]:
            assert (projects[0]/name).read_bytes() == (projects[1]/name).read_bytes(), (method, name)
    rows = list(csv.DictReader((projects[1] / "long.csv").read_text().splitlines()))
    partial = {row["raw_data_filename"]: row for row in rows if row["feature_name"] == "Partial"}
    assert partial["first.mzML"]["area"] and partial["last.mzML"]["area"]
    assert not any(partial["middle.mzML"][col] for col in
                   ("area", "height", "FWHM", "trace_cut_pct", "sn_ratio", "noise_method", "polarity", "collision_energy"))
    assert all(row["feature_name"] != "NoRef" for row in rows)
    metrics = (projects[1] / "misc" / "peak_metrics.bin").read_bytes()
    assert len(metrics) == 16 * len(rows)
    for metrics_row, row in zip(struct.iter_unpack("<4f", metrics), rows):
        for value, column, digits in zip(metrics_row, ("height", "FWHM", "trace_cut_pct", "sn_ratio"), (1, 3, 1, 1)):
            assert (f"{value:.{digits}f}" if math.isfinite(value) else "") == row[column], (value, column, row)
    if shutil.which("Rscript"):
        run(workers[1], 4)
        samples = list((projects[1] / "by_sample").glob("*.pdf"))
        transitions = list((projects[1] / "by_transition").glob("*.pdf"))
        transitions.extend((projects[1] / "by_transition_low").glob("*.pdf"))
        assert len(samples) == 1 and len(transitions) == 2
        assert all(path.read_bytes().startswith(b"%PDF-") for path in samples + transitions)
    # Edits copied to every sample must never create a measurement for an absent trace.
    matrix = projects[1] / "RT_matrix.csv"
    with matrix.open(newline="") as stream:
        records = list(csv.reader(stream))
    columns = [j for j, value in enumerate(records[0]) if value.startswith("Partial / ")]
    for j in columns:
        records[4][j] = records[3][j]
    with matrix.open("w", newline="") as stream:
        csv.writer(stream).writerows(records)
    run(workers[1], 3)
    rows = list(csv.DictReader((projects[1] / "long.csv").read_text().splitlines()))
    assert not next(row for row in rows if row["feature_name"] == "Partial" and row["raw_data_filename"] == "middle.mzML")["area"]
    # Two bad inputs must both be named, preserving all of the previous extraction.
    prior = {p.name: p.read_bytes() for p in (projects[1] / "misc").iterdir() if p.is_file()}
    # The lightweight preflight succeeds on the first array of this file. An
    # error later in extraction still names the file and preserves the cache.
    later = projects[1] / "mzML" / "last.mzML"
    original = later.read_text()
    split = original.rindex("<binary>") + len("<binary>")
    later.write_text(original[:split] + "!" + original[split+1:])
    result = subprocess.run([str(workers[1]), "1"], cwd=projects[1], capture_output=True, timeout=30)
    assert result.returncode and b"last.mzML" in result.stderr
    assert prior == {p.name: p.read_bytes() for p in (projects[1] / "misc").iterdir() if p.is_file()}
    later.write_text(original)
    for name in ["first", "middle"]:
        (projects[1] / "mzML" / f"{name}.mzML").write_text("<mzML/>")
    result = subprocess.run([str(workers[1]), "1"], cwd=projects[1], timeout=30)
    assert result.returncode != 0
    report = (projects[1] / "mzml_format_errors.txt").read_text()
    assert all(f"{name}.mzML" in report for name in ["first", "middle"])
    assert prior == {p.name: p.read_bytes() for p in (projects[1] / "misc").iterdir() if p.is_file()}
    print("PASS worker output parity, missing middle sample, edited bounds and format preflight")


if __name__ == "__main__":
    with tempfile.TemporaryDirectory() as directory:
        verify(Path(directory), *[Path(arg).resolve() for arg in sys.argv[1:]])
