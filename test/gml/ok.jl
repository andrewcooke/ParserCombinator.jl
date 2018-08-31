

@testset "ok" begin

@test parse_raw("a 1") == Any[Any[(:a,1)]]

@test parse_raw("a 1.0") == Any[Any[(:a,1.0)]]

@test parse_raw("a \"b\"") == Any[Any[(:a,"b")]]

@test parse_raw(" a 1") == Any[Any[(:a,1)]]

@test parse_raw(" a 1.0") == Any[Any[(:a,1.0)]]

@test parse_raw(" a \"b\"") == Any[Any[(:a,"b")]]

@test parse_raw("a 1 ") == Any[Any[(:a,1)]]

@test parse_raw("a 1.0 ") == Any[Any[(:a,1.0)]]

@test parse_raw("a \"b\" ") == Any[Any[(:a,"b")]]

@test parse_raw("a [b 1]") == Any[Any[(:a,Any[(:b,1)])]]

@test parse_raw(" a [b 1]") == Any[Any[(:a,Any[(:b,1)])]]

@test parse_raw("a [ b 1]") == Any[Any[(:a,Any[(:b,1)])]]

@test parse_raw("a [b 1 ]") == Any[Any[(:a,Any[(:b,1)])]]

@test parse_raw("a [b 1] ") == Any[Any[(:a,Any[(:b,1)])]]

@test parse_raw("a [b [c 1]]") == Any[Any[(:a,Any[(:b,Any[(:c,1)])])]]

@test parse_raw("a [b [c 1 d 2.0 e \"3\"]]") == Any[Any[(:a,Any[(:b,Any[(:c,1),(:d,2.0),(:e,"3")])])]]

end
