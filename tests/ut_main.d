import unit_threaded.runner.runner;

int main(string[] args) {
    return runTests!(
          "ut.toml",
          "ut.invalid",
          "ut.valid",
          "toml.serialize",
          "toml.toml",
          )(args);
}
