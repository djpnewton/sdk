// Method to test: function(foo)
import 'package:expect/expect.dart';

@NoInline() foo(a) => a % 13;

main() {
  print(foo(5));
  print(foo(-100));
}
