#include <cstring>
#include <iostream>

#include <openssl/evp.h>
#include <openssl/opensslconf.h>

int main()
{
    std::cout << OPENSSL_VERSION_TEXT << '\n';

    EVP_MD_CTX* mdctx;
    const EVP_MD* md;
    char mess1[] = "Test Message\n";
    char mess2[] = "Hello World\n";
    unsigned char md_value[EVP_MAX_MD_SIZE];
    unsigned int md_len, i;

    md = EVP_get_digestbyname("md5");
    if (md == NULL) {
        std::cout << "Unknown message digest\n";
        return 1;
    }

    mdctx = EVP_MD_CTX_new();
    EVP_DigestInit_ex(mdctx, md, NULL);
    EVP_DigestUpdate(mdctx, mess1, std::strlen(mess1));
    EVP_DigestUpdate(mdctx, mess2, std::strlen(mess2));
    EVP_DigestFinal_ex(mdctx, md_value, &md_len);
    EVP_MD_CTX_free(mdctx);

    std::cout << "Expected : ce73931d2b3da6e6bf18af27494c6cd\n"
              << "Generate : ";
    for (i = 0; i < md_len; i++)
        std::cout << std::hex << static_cast<int>(md_value[i]);

    return 0;
}