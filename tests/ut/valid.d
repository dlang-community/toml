module ut.valid;

import unit_threaded;
import toml;


@("issue5")
@ShouldFail("to be fixed: see https://github.com/dlang-community/toml/issues/5")
@safe
unittest {
   enum T =`
      [[override]]
      a = 30

      [override.symbols]
      "S.f" = 30

      [[override]]
      a = 40

      [override.symbols]
      "S.f" = 25 `;
   TOMLDocument doc = parseTOML(T);
}
