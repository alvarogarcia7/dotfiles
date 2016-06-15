require 'date'

# Save the session at a local file
Kernel.at_exit {
  File.open("repl.log", "a") do
    |f|
      f << "\n#Session ending at: "
      f << DateTime.now
      f << "\n"
      f << Readline::HISTORY.to_a.join("\n")
  end
}
