#include <iostream>

#include <openssl/opensslconf.h>

int main()
{
    std::cout << OPENSSL_VERSION_TEXT << '\n';

    return 0;
}