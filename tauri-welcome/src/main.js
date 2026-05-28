const okButton = document.getElementById("ok-btn");
const result = document.getElementById("result");

const invoke = window.__TAURI__?.core?.invoke;

okButton?.addEventListener("click", async () => {
  if (!result) {
    return;
  }

  if (typeof invoke !== "function") {
    result.textContent = "Tauri backend is not available";
    result.hidden = false;
    console.error("window.__TAURI__.core.invoke is unavailable", window.__TAURI__);
    return;
  }

  try {
    const message = await invoke("ok_pressed");
    result.textContent = String(message);
    result.hidden = false;
  } catch (error) {
    result.textContent = "Backend call failed";
    result.hidden = false;
    console.error(error);
  }
});
