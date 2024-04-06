#pragma once

/*
 * C++ implementation of LZ-String, version 1.4.4
 * https://github.com/pieroxy/lz-string
 * https://github.com/andykras/lz-string-cpp
 *
 * MIT License
 *
 * Copyright (c) 2021 Andrey Krasnov
 *
 */

#include <string>
#include <unordered_map>

// preserve all original comments and naming from
// https://github.com/pieroxy/lz-string/blob/master/libs/lz-string.js
namespace lzstring
{
#ifdef _MSC_VER
using string = std::wstring;
#  ifndef _U
#    define _U(x) L##x
#  endif
#else
using string = std::u16string;
#include <uchar.h>
#  ifndef _U
#    define _U(x) u##x
#  endif
#endif
namespace __inner
{
  const string keyStrBase64{_U("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/=")};
  const string::value_type equal{_U('=')};

  int charCodeAt(const string& str, int pos)
  {
    return static_cast<int>(str.at(pos));
  }

  string f(int ascii)
  {
    return {static_cast<string::value_type>(ascii)};
  }

  template <typename Fn>
  string _compress(const string& uncompressed, int bitsPerChar, Fn getCharFromInt)
  {
    int i = 0;
    int value = 0;

    std::unordered_map<string, int> context_dictionary;
    std::unordered_map<string, bool> context_dictionaryToCreate;

    string context_c;
    string context_wc;
    string context_w;

    int context_enlargeIn = 2; // Compensate for the first entry which should not count
    int context_dictSize = 3;
    int context_numBits = 2;

    string context_data;
    int context_data_val = 0;
    int context_data_position = 0;

    for (size_t ii = 0; ii < uncompressed.length(); ++ii)
    {
      context_c = uncompressed.at(ii);
      if (context_dictionary.count(context_c) == 0)
      {
        context_dictionary[context_c] = context_dictSize++;
        context_dictionaryToCreate[context_c] = true;
      }

      context_wc = context_w + context_c;
      if (context_dictionary.count(context_wc) > 0)
      {
        context_w = context_wc;
      }
      else
      {
        auto context_w_it = context_dictionaryToCreate.find(context_w);
        if (context_w_it != context_dictionaryToCreate.end())
        {
          if (charCodeAt(context_w, 0) < 256)
          {
            for (i = 0; i < context_numBits; ++i)
            {
              context_data_val = (context_data_val << 1);
              if (context_data_position == bitsPerChar - 1)
              {
                context_data_position = 0;
                context_data.push_back(getCharFromInt(context_data_val));
                context_data_val = 0;
              }
              else
              {
                ++context_data_position;
              }
            }
            value = charCodeAt(context_w, 0);
            for (i = 0; i < 8; ++i)
            {
              context_data_val = (context_data_val << 1) | (value & 1);

              if (context_data_position == bitsPerChar - 1)
              {
                context_data_position = 0;
                context_data.push_back(getCharFromInt(context_data_val));
                context_data_val = 0;
              }
              else
              {
                ++context_data_position;
              }
              value = value >> 1;
            }
          }
          else
          {
            value = 1;
            for (i = 0; i < context_numBits; ++i)
            {
              context_data_val = (context_data_val << 1) | value;
              if (context_data_position == bitsPerChar - 1)
              {
                context_data_position = 0;
                context_data.push_back(getCharFromInt(context_data_val));
                context_data_val = 0;
              }
              else
              {
                ++context_data_position;
              }
              value = 0;
            }
            value = charCodeAt(context_w, 0);
            for (i = 0; i < 16; ++i)
            {
              context_data_val = (context_data_val << 1) | (value & 1);
              if (context_data_position == bitsPerChar - 1)
              {
                context_data_position = 0;
                context_data.push_back(getCharFromInt(context_data_val));
                context_data_val = 0;
              }
              else
              {
                ++context_data_position;
              }
              value = value >> 1;
            }
          }
          if (--context_enlargeIn == 0)
          {
            context_enlargeIn = 1 << context_numBits; // Math.pow(2, context_numBits);
            ++context_numBits;
          }
          context_dictionaryToCreate.erase(context_w_it); // delete context_dictionaryToCreate[context_w];
        }
        else
        {
          value = context_dictionary[context_w];
          for (i = 0; i < context_numBits; ++i)
          {
            context_data_val = (context_data_val << 1) | (value & 1);
            if (context_data_position == bitsPerChar - 1)
            {
              context_data_position = 0;
              context_data.push_back(getCharFromInt(context_data_val));
              context_data_val = 0;
            }
            else
            {
              ++context_data_position;
            }
            value = value >> 1;
          }
        }
        if (--context_enlargeIn == 0)
        {
          context_enlargeIn = 1 << context_numBits; // Math.pow(2, context_numBits);
          ++context_numBits;
        }
        // Add wc to the dictionary.
        context_dictionary[context_wc] = context_dictSize++;
        context_w = context_c; // context_w = String(context_c);
      }
    }

    // Output the code for w.
    if (!context_w.empty())
    {
      auto context_w_it = context_dictionaryToCreate.find(context_w);
      if (context_w_it != context_dictionaryToCreate.end())
      {
        if (charCodeAt(context_w, 0) < 256)
        {
          for (i = 0; i < context_numBits; ++i)
          {
            context_data_val = (context_data_val << 1);
            if (context_data_position == bitsPerChar - 1)
            {
              context_data_position = 0;
              context_data.push_back(getCharFromInt(context_data_val));
              context_data_val = 0;
            }
            else
            {
              ++context_data_position;
            }
          }
          value = charCodeAt(context_w, 0);
          for (i = 0; i < 8; ++i)
          {
            context_data_val = (context_data_val << 1) | (value & 1);
            if (context_data_position == bitsPerChar - 1)
            {
              context_data_position = 0;
              context_data.push_back(getCharFromInt(context_data_val));
              context_data_val = 0;
            }
            else
            {
              ++context_data_position;
            }
            value = value >> 1;
          }
        }
        else
        {
          value = 1;
          for (i = 0; i < context_numBits; ++i)
          {
            context_data_val = (context_data_val << 1) | value;
            if (context_data_position == bitsPerChar - 1)
            {
              context_data_position = 0;
              context_data.push_back(getCharFromInt(context_data_val));
              context_data_val = 0;
            }
            else
            {
              ++context_data_position;
            }
            value = 0;
          }
          value = charCodeAt(context_w, 0);
          for (i = 0; i < 16; ++i)
          {
            context_data_val = (context_data_val << 1) | (value & 1);
            if (context_data_position == bitsPerChar - 1)
            {
              context_data_position = 0;
              context_data.push_back(getCharFromInt(context_data_val));
              context_data_val = 0;
            }
            else
            {
              ++context_data_position;
            }
            value = value >> 1;
          }
        }
        if (--context_enlargeIn == 0)
        {
          context_enlargeIn = 1 << context_numBits; // Math.pow(2, context_numBits);
          ++context_numBits;
        }
        context_dictionaryToCreate.erase(context_w_it); // delete context_dictionaryToCreate[context_w];
      }
      else
      {
        value = context_dictionary[context_w];
        for (i = 0; i < context_numBits; ++i)
        {
          context_data_val = (context_data_val << 1) | (value & 1);
          if (context_data_position == bitsPerChar - 1)
          {
            context_data_position = 0;
            context_data.push_back(getCharFromInt(context_data_val));
            context_data_val = 0;
          }
          else
          {
            ++context_data_position;
          }
          value = value >> 1;
        }
      }
      if (--context_enlargeIn == 0)
      {
        context_enlargeIn = 1 << context_numBits; // Math.pow(2, context_numBits);
        ++context_numBits;
      }
    }

    // Mark the end of the stream
    value = 2;
    for (i = 0; i < context_numBits; ++i)
    {
      context_data_val = (context_data_val << 1) | (value & 1);
      if (context_data_position == bitsPerChar - 1)
      {
        context_data_position = 0;
        context_data.push_back(getCharFromInt(context_data_val));
        context_data_val = 0;
      }
      else
      {
        ++context_data_position;
      }
      value = value >> 1;
    }

    // Flush the last char
    while (true)
    {
      context_data_val = (context_data_val << 1);
      if (context_data_position == bitsPerChar - 1)
      {
        context_data.push_back(getCharFromInt(context_data_val));
        break;
      }
      else
      {
        ++context_data_position;
      }
    }

    return context_data;
  }

  template <typename Fn>
  string _decompress(int length, int resetValue, Fn getNextValue)
  {
    std::unordered_map<int, string> dictionary;

    int next = 0;
    int enlargeIn = 4;
    int dictSize = 4;
    int numBits = 3;
    string entry;
    string result;
    string w;
    int bits, resb, maxpower, power;
    string c;

    struct
    {
      int val, position, index;
    } data{getNextValue(0), resetValue, 1};

    bits = 0;
    maxpower = 4; // Math.pow(2, 2);
    power = 1;

    while (power != maxpower)
    {
      resb = data.val & data.position;
      data.position >>= 1;
      if (data.position == 0)
      {
        data.position = resetValue;
        data.val = getNextValue(data.index++);
      }
      bits |= (resb > 0 ? 1 : 0) * power;
      power <<= 1;
    }

    switch (next = bits)
    {
    case 0:
      bits = 0;
      maxpower = 256; // Math.pow(2, 8);
      power = 1;
      while (power != maxpower)
      {
        resb = data.val & data.position;
        data.position >>= 1;
        if (data.position == 0)
        {
          data.position = resetValue;
          data.val = getNextValue(data.index++);
        }
        bits |= (resb > 0 ? 1 : 0) * power;
        power <<= 1;
      }
      c = f(bits);
      break;

    case 1:
      bits = 0;
      maxpower = 65536; // Math.pow(2, 16);
      power = 1;
      while (power != maxpower)
      {
        resb = data.val & data.position;
        data.position >>= 1;
        if (data.position == 0)
        {
          data.position = resetValue;
          data.val = getNextValue(data.index++);
        }
        bits |= (resb > 0 ? 1 : 0) * power;
        power <<= 1;
      }
      c = f(bits);
      break;

    case 2:
      return {};
    }

    dictionary[3] = c;
    w = c;
    result += c;

    while (true)
    {
      if (data.index > length)
      {
        return {};
      }

      bits = 0;
      maxpower = 1 << numBits; // Math.pow(2, numBits);
      power = 1;
      while (power != maxpower)
      {
        resb = data.val & data.position;
        data.position >>= 1;
        if (data.position == 0)
        {
          data.position = resetValue;
          data.val = getNextValue(data.index++);
        }
        bits |= (resb > 0 ? 1 : 0) * power;
        power <<= 1;
      }

      int c;
      switch (c = bits)
      {
      case 0:
        bits = 0;
        maxpower = 256; // Math.pow(2, 8);
        power = 1;
        while (power != maxpower)
        {
          resb = data.val & data.position;
          data.position >>= 1;
          if (data.position == 0)
          {
            data.position = resetValue;
            data.val = getNextValue(data.index++);
          }
          bits |= (resb > 0 ? 1 : 0) * power;
          power <<= 1;
        }

        dictionary[dictSize++] = f(bits);
        c = dictSize - 1;
        enlargeIn--;
        break;

      case 1:
        bits = 0;
        maxpower = 65536; // Math.pow(2, 16);
        power = 1;
        while (power != maxpower)
        {
          resb = data.val & data.position;
          data.position >>= 1;
          if (data.position == 0)
          {
            data.position = resetValue;
            data.val = getNextValue(data.index++);
          }
          bits |= (resb > 0 ? 1 : 0) * power;
          power <<= 1;
        }
        dictionary[dictSize++] = f(bits);
        c = dictSize - 1;
        enlargeIn--;
        break;

      case 2:
        return result;
      }

      if (enlargeIn == 0)
      {
        enlargeIn = 1 << numBits; // Math.pow(2, numBits);
        numBits++;
      }

      if (!dictionary[c].empty())
      {
        entry = dictionary[c];
      }
      else
      {
        if (c == dictSize)
        {
          entry = w + w.at(0);
        }
        else
        {
          return {};
        }
      }
      result += entry;

      // Add w+entry[0] to the dictionary.
      dictionary[dictSize++] = w + entry.at(0);
      enlargeIn--;

      w = entry;

      if (enlargeIn == 0)
      {
        enlargeIn = 1 << numBits; // Math.pow(2, numBits);
        numBits++;
      }
    }

    return {};
  }

} // namespace __inner

// clang-format off
string compressToBase64(const string& input)
{
  if (input.empty()) return {};
  using namespace __inner;
  auto res = _compress(input, 6, [](int a) { return keyStrBase64.at(a); });
  switch (res.length() % 4) { // To produce valid Base64
  default: // When could this happen ?
  case 0 : return res;
  case 1 : return res+string(3,equal);
  case 2 : return res+string(2,equal);
  case 3 : return res+string(1,equal);
  }
}

string decompressFromBase64(const string& input)
{
  if (input.empty()) return {};
  using namespace __inner;
  std::unordered_map<string::value_type, int> baseReverseDic;
  for (int i = 0; i < keyStrBase64.length(); ++i) baseReverseDic[keyStrBase64.at(i)] = i;
  return _decompress(input.length(), 32, [&](int index) { return baseReverseDic[input.at(index)]; });
}
// clang-format on

} // namespace lzstring
