export async function showRenameNotice(invoke) {
  const notice = await invoke("rename_notice");
  if (!notice) return;
  const dialog = document.createElement("dialog");
  dialog.className = "rename-notice";
  dialog.setAttribute("aria-labelledby", "rename-notice-title");
  dialog.innerHTML = `<h2 id="rename-notice-title">Now named MRMhub GUI</h2><p>The app has a shorter name. A separate installation named MRMhub Integrator GUI was found. You can remove the old app to avoid opening it by mistake.</p><p class="rename-paths"></p><p class="rename-instructions"></p><p class="rename-result" role="status"></p><div class="rename-notice-actions"><button type="button" class="rename-trash">Move old app to Trash</button><button type="button" class="rename-dismiss" autofocus>Keep both</button></div>`;
  dialog.querySelector(".rename-paths").textContent = notice.paths.join("\n");
  dialog.querySelector(".rename-instructions").textContent = notice.instructions;
  const trash = dialog.querySelector(".rename-trash"), dismiss = dialog.querySelector(".rename-dismiss");
  const result = dialog.querySelector(".rename-result");
  trash.hidden = !notice.canTrash;
  if (!notice.canTrash) dismiss.textContent = "Got it";
  document.body.append(dialog);
  let pending = false;
  trash.onclick = async () => {
    pending = true; trash.disabled = true; dismiss.disabled = true;
    result.textContent = "Moving the old app to Trash…";
    try { result.textContent = await invoke("rename_trash_old_app"); }
    catch (error) { result.textContent = `The old app could not be moved: ${error}. Please use the manual instructions above.`; }
    finally { pending = false; dismiss.disabled = false; dismiss.textContent = "Done"; dismiss.focus(); }
  };
  await new Promise(resolve => {
    dismiss.onclick = () => dialog.close();
    dialog.addEventListener("cancel", event => { if (pending) event.preventDefault(); });
    dialog.addEventListener("close", resolve, { once: true });
    dialog.showModal();
  });
  dialog.remove();
  await invoke("rename_notice_acknowledge");
}
