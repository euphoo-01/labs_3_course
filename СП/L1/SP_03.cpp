#include <stdio.h>
#include "SP_XX.h"

int main()
{
    int x = 10;
    int y = 2;

    printf("sum(%d, %d) = %d\n", x, y, sum(x, y));
    printf("sub(%d, %d) = %d\n", x, y, sub(x, y));
    printf("mul(%d, %d) = %d\n", x, y, mul(x, y));
    printf("div(%d, %d) = %d\n", x, y, div(x, y));

    return 0;
}
