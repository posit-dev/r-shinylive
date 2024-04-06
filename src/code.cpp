#include <cpp11.hpp>
#include <codecvt>
#include "lz-string.hpp"
using namespace cpp11;

[[cpp11::register]]
std::string compressToEncodedURIComponent(std::string uncompressed8) {
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter_8_to_16;
  std::u16string uncompressed16 = converter_8_to_16.from_bytes(uncompressed8);

  auto compressed16 = lzstring::compressToEncodedURIComponent(uncompressed16);

  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter_16_to_8;
  std::string compressed8 = converter_16_to_8.to_bytes(compressed16);

  return compressed8;
}


[[cpp11::register]]
std::string decompressFromEncodedURIComponent(std::string compressed8) {
  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter_8_to_16;
  std::u16string compressed16 = converter_8_to_16.from_bytes(compressed8);

  auto uncompressed16 = lzstring::decompressFromEncodedURIComponent(compressed16);

  std::wstring_convert<std::codecvt_utf8_utf16<char16_t>, char16_t> converter_16_to_8;
  std::string uncompressed8 = converter_16_to_8.to_bytes(uncompressed16);

  return uncompressed8;
}
