# character_format_parse() / checks versions and required capabilities with zero-based paths

    Code
      message(conditionMessage(error))
    Message
      $.format_version: This file is format version 2; this mascot version supports 1. Update the package, or use a version-1 file.

---

    Code
      message(conditionMessage(error))
    Message
      $.format_version: This file is format version 99; this mascot version supports 1. Update the package, or use a version-1 file.

---

    Code
      message(conditionMessage(error))
    Message
      $.format_version: This file is format version 100000; this mascot version supports 1. Update the package, or use a version-1 file.

---

    Code
      message(conditionMessage(error))
    Message
      $.format_version: Format version 0 is not a supported version; this mascot version supports 1. Use a version-1 file.

---

    Code
      message(conditionMessage(error))
    Message
      $.format_version: Format version -1 is not a supported version; this mascot version supports 1. Use a version-1 file.

