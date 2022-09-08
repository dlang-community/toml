module ut.invalid;

import std.experimental.logger;
import unit_threaded;
import toml;

// based on https://github.com/BurntSushi
@ShouldFail("to be fixed")
@Name("after-array")
unittest {
   enum T = `[[agencies]] owner = "S Cjelli"`;
   parseTOML(T).shouldThrow;
}


@("duplicate")
unittest {
   enum T = `# DO NOT DO THIS
      name = "Tom"
      name = "Pradyun"
      `;
   parseTOML(T).shouldThrow;
}

//tests/invalid/table/duplicate-key-dotted-table.toml
@ShouldFail("to be fixed")
@("duplicate-key")
unittest {
   enum T = `
      [fruit]
      apple.color = "red"
      [fruit.apple] # INVALID`;
   parseTOML(T).shouldThrow;
}
