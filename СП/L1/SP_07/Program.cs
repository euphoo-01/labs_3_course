using System;
using System.Runtime.InteropServices;

class Program
{
    [DllImport("SP_XX.so", EntryPoint = "sum",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int Sum(int x, int y);

    [DllImport("SP_XX.so", EntryPoint = "sub",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int Sub(int x, int y);

    [DllImport("SP_XX.so", EntryPoint = "mul",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int Mul(int x, int y);

    [DllImport("SP_XX.so", EntryPoint = "div",
        CallingConvention = CallingConvention.Cdecl)]
    private static extern int Div(int x, int y);

    static void Main()
    {
        int x = 10;
        int y = 2;

        Console.WriteLine($"sum({x}, {y}) = {Sum(x, y)}");
        Console.WriteLine($"sub({x}, {y}) = {Sub(x, y)}");
        Console.WriteLine($"mul({x}, {y}) = {Mul(x, y)}");
        Console.WriteLine($"div({x}, {y}) = {Div(x, y)}");
    }
}
