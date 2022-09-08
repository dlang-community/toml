import reggae;
alias app = scriptlike!(App(SourceFileName(`app.d`), BinaryFileName(`dtoml_dec`)),
                               Flags(),
                               ImportPaths([`../src`]),
    );
mixin build!(app);
