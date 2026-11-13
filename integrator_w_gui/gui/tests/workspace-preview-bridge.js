// All data and mutations below are in-memory fixtures only.
(() => {
  const events = new Map();
  const bytes = (text) => new TextEncoder().encode(text);
  const project = {
    name: "MRMhub demo",
    path: "/__mrmhub_ui_preview__/Dataset4",
    sampleCount: 8,
    transitionFile: "transition_list.csv",
    issues: [],
    canRun: true,
    outputs: {
      validated: true,
      detected: true,
      integrated: true,
      plotted: false,
    },
  };
  const original = "RT_matrix_original.csv",
    saved = "RT_matrix_2026-10-04_12-00-00.csv";
  let backups = [original, saved], last = original;
  const file = {
    kind: "param",
    title: "Parameters",
    name: "param.txt",
    format: "text",
  };
  const content = {
    file,
    text: "# Synthetic UI test\nthreads = 4\n",
    backups: ["original.txt"],
  };
  const transitionFile = {
    kind: "transitions",
    title: "Transitions",
    name: "transition_list.csv",
    format: "csv",
  };
  const transitionContent = {
    file: transitionFile,
    backups: [],
    headers: ["Name", "Precursor_mz", "Product_mz"],
    rows: [["CE 16:1", "640.600", "369.300"], [
      "PC 34:2",
      "758.600",
      "184.100",
    ]],
  };
  const editedWindows = new Map();
  const plot = (index, cqq = "1") => ({
    sh: index / 100,
    // Mix old/detected-only traces with integrated traces to catch missing fills.
    bl: index % 2 ? [0, 0] : [null, null],
    pos_l: editedWindows.has(`${cqq}:${index}`)
      ? [Math.round(editedWindows.get(`${cqq}:${index}`).rtStart * 10) + 1, Math.round(editedWindows.get(`${cqq}:${index}`).rtEnd * 10) + 1]
      : [25, 65],
    te: Array.from(
      { length: 101 },
      (_, i) => ({
        x: i / 10,
        y: 25000 * Math.exp(-Math.pow((i - 45 - index) / 12, 2)),
      }),
    ),
  });
  window.__TAURI__ = {
    dialog: { open: async () => null, save: async () => null },
    event: {
      listen: async (name, callback) => {
        events.set(name, callback);
        return () => events.delete(name);
      },
    },
    core: {
      Channel: class {
        onmessage() {}
      },
      invoke: async (command, args = {}) => {
        switch (command) {
          case "rename_notice":
            return null;
          case "load_startup_state":
            return { project, theme: "light" };
          case "missing_project_files":
            return { files: [] };
          case "set_theme":
            return;
          case "refresh_project":
          case "select_project":
            return project;
          case "run_step": {
            events.get("worker-output")?.({
              payload: {
                step: args.step,
                line: "Synthetic processing output",
                stream: "stdout",
              },
            });
            return project;
          }
          case "backup_rtmatrix":
            return saved;
          case "visualizer_get_ref":
            return ["REFSample_1.mzML"];
          case "visualizer_trans_csv":
            return bytes(
              "id,name,precursor,product\nC1,CE 16:1,640.600,369.300\nC2,PC 34:2,758.600,184.100\n",
            );
          case "visualizer_mzml_tsv":
            return bytes(
              Array.from(
                { length: 8 },
                (_, i) =>
                  `Sample_${i + 1}.mzML\t${i % 3 === 0 ? "QC" : "Sample"}\t2026-10-11T00:${String(i * 5).padStart(2, "0")}:00Z\t${i < 4 ? "1" : "2"}\t${i === 0 ? "1" : "0"}`,
              ).join("\n"),
            );
          case "visualizer_get_sh":
            return [0, .03, -.02, .01, .04, -.01, 0, .02];
          case "visualizer_read_long":
            return [[
              "CE 16:1",
              Array.from(
                { length: 8 },
                (_, i) => ({
                  area: 100000 + i * 2000,
                  height: 20000 + i * 100,
                }),
              ),
            ]];
          case "visualizer_get_t":
          case "visualizer_get_r":
            for (let i = 0; i < (command.endsWith("_t") ? 8 : 2); i++) {
              args
                .onEvent.onmessage(plot(i, args.cqq));
            }
            return;
          case "list_rtmatrix_backups":
            return {
              backups,
              last,
              labels: { [saved]: "Adjusted integration" },
            };
          case "restore_rtmatrix_backup":
            return;
          case "set_last_backup":
            last = args.name;
            return;
          case "visualizer_align_shared_bounds":
            return {
              written: 8,
              shifted: 7,
              referenceProfiles: 1,
              averageScore: .97,
            };
          case "visualizer_save_shared_bounds":
            return 8;
          case "visualizer_save_bounds":
            for (const edit of args.edits) editedWindows.set(`${edit.cqq}:${edit.sampleIndex}`, edit);
            return args.edits.length;
          case "delete_all_rtmatrix_backups":
            backups = [original];
            return 1;
          case "data_editor_files":
            return [file, transitionFile];
          case "data_editor_read":
          case "data_editor_read_backup":
            return args.kind === "transitions" ? transitionContent : content;
          case "scratchpad_list_notes":
            return [];
          case "terminal_start":
            args.output.onmessage({ kind: "data", id: 1, data: Array.from(bytes(
              "In-memory UI test terminal — no system shell or commands.\r\n" +
              "\u001b[31mError sample\u001b[0m · \u001b[32mSuccess sample\u001b[0m · " +
              "\u001b[34mInfo sample\u001b[0m · \u001b[97mBright white sample\u001b[0m\r\n$ ",
            )) });
            return { id: 1, shell: "UI test terminal", home: "/__mrmhub_ui_preview__" };
          case "terminal_write":
          case "terminal_resize":
          case "terminal_ack":
          case "terminal_stop":
            return;
          case "quant_history":
            return [];
          case "quant_storage":
            return { folder: `${project.path}/QUANT`, totalBytes: 2_450_000_000, reclaimableBytes: 1_200_000_000, trashBytes: 340_000_000, files: 142, skippedEntries: 0 };
          case "quant_compact":
            return { retiredSnapshotBytes: 0 };
          case "quant_status":
            return {
              ready: true,
              catalog: {
                version: "UI preview",
                operations: [
                  {
                    id: "import_data_mrmhub",
                    kind: "import",
                    label: "Import MRMhub results",
                    stage: "1 · Import",
                    fields: [],
                  },
                  {
                    id: "plot_runsequence",
                    kind: "plot",
                    label: "Run sequence",
                    stage: "3 · Inspect",
                    fields: [],
                  },
                ],
              },
              message: "Synthetic preview — no R or dataset access",
            };
          default:
            throw Error(`Unsupported preview command: ${command}`);
        }
      },
    },
  };
})();
