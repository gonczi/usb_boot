#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

use std::fs;

#[tauri::command]
fn ok_pressed() -> String {
    let path = "/tmp/ok_pressed";

    let next_value = fs::read_to_string(path)
        .ok()
        .and_then(|content| content.trim().parse::<u64>().ok())
        .map(|value| value.saturating_add(1))
        .unwrap_or(1);

    let _ = fs::write(path, next_value.to_string());

    format!("You pressed the button {} times", next_value)
}

fn main() {
    tauri::Builder::default()
        .invoke_handler(tauri::generate_handler![ok_pressed])
        .run(tauri::generate_context!())
        .expect("error while running tauri application");
}
