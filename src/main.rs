use chrono::Datelike;
use std::io::Write;

fn main() -> Result<(), std::io::Error> {
    // Return the file path of todays note (creating it if it doesn't exist)
    let current_date = chrono::Local::now().format("%Y-%m-%d").to_string();
    let mut file_path = dirs::home_dir().expect("Cannot access home dir");
    file_path.push("notes/journal");
    file_path.push(current_date + ".md");
    if std::fs::exists(file_path.clone())? {
        return std::io::stdout().write_all(file_path.clone().as_os_str().as_encoded_bytes());
    }

    let mut templates_dir = std::env::var("TEMPLATES_DIR").unwrap();
    templates_dir.push_str("/*.template");
    let tera = match tera::Tera::new(templates_dir.as_str()) {
        Ok(t) => t,
        Err(e) => {
            println!("Parsing error(s): {}", e);
            ::std::process::exit(1);
        }
    };

    // # Core / Legs / Back / Hips
    let current_day_of_year = chrono::Utc::now().ordinal();
    let number_of_workouts = 3 as u32;
    let day_idx = current_day_of_year % number_of_workouts;
    let workout = match day_idx {
        0 => "core",
        1 => "legs",
        2 => "back",
        _ => panic!(),
    };

    // Get previous day's "What I want to do tomorrow" section
    let prev_day = chrono::Local::now() - chrono::Duration::days(1);
    let prev_date = prev_day.format("%Y-%m-%d").to_string();
    let mut prev_file_path = dirs::home_dir().expect("Cannot access home dir");
    prev_file_path.push("notes/journal");
    prev_file_path.push(prev_date + ".md");

    let todo_content = if std::fs::exists(&prev_file_path).unwrap_or(false) {
        std::fs::read_to_string(&prev_file_path)
            .ok()
            .and_then(|content| extract_tomorrow_section(&content))
    } else {
        None
    };

    let mut context = tera::Context::new();
    context.insert("workout", workout);
    context.insert("todo_content", &todo_content);

    let str_to_write = tera
        .render("journal.template", &context)
        .expect("unable to write to template");
    let buf = str_to_write.as_bytes();

    // Create file
    let mut file = std::fs::File::create(file_path.clone())?;
    file.write_all(buf)?;

    std::io::stdout().write_all(file_path.as_os_str().as_encoded_bytes())
}

fn extract_tomorrow_section(content: &str) -> Option<String> {
    let lines: Vec<&str> = content.lines().collect();
    let mut in_tomorrow_section = false;
    let mut todo_lines = Vec::new();

    for line in lines {
        if line.trim() == "### What I want to do tomorrow" {
            in_tomorrow_section = true;
            continue;
        }

        if in_tomorrow_section {
            // Stop at next heading or end of file
            if line.starts_with("#") {
                break;
            }
            // Collect non-empty lines
            if !line.trim().is_empty() {
                todo_lines.push(line);
            }
        }
    }

    if todo_lines.is_empty() {
        None
    } else {
        Some(todo_lines.join("\n"))
    }
}
