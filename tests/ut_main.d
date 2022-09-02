import unit_threaded.runner.runner;

int main(string[] args) {
    return runTests!(
          "ut.toml",
          "ut.invalid",
          "toml.serialize",
          "toml.toml",
          )(args);
}
