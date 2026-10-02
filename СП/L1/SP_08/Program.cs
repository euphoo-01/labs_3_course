using System;
using System.Runtime.InteropServices;

class Program
{
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    private delegate int BinaryOperation(int x, int y);

    static void Main()
    {
        IntPtr library = NativeLibrary.Load("./SP_XX.so");

        IntPtr sumAddress =
            NativeLibrary.GetExport(library, "sum");

        IntPtr subAddress =
            NativeLibrary.GetExport(library, "sub");

        IntPtr mulAddress =
            NativeLibrary.GetExport(library, "mul");

        IntPtr divAddress =
            NativeLibrary.GetExport(library, "div");

        BinaryOperation sum =
            Marshal.GetDelegateForFunctionPointer<BinaryOperation>(sumAddress);

        BinaryOperation sub =
            Marshal.GetDelegateForFunctionPointer<BinaryOperation>(subAddress);

        BinaryOperation mul =
            Marshal.GetDelegateForFunctionPointer<BinaryOperation>(mulAddress);

        BinaryOperation div =
            Marshal.GetDelegateForFunctionPointer<BinaryOperation>(divAddress);

        int x = 10;
        int y = 2;

        Console.WriteLine($"sum({x}, {y}) = {sum(x, y)}");
        Console.WriteLine($"sub({x}, {y}) = {sub(x, y)}");
        Console.WriteLine($"mul({x}, {y}) = {mul(x, y)}");
        Console.WriteLine($"div({x}, {y}) = {div(x, y)}");

        NativeLibrary.Free(library);
    }
}
