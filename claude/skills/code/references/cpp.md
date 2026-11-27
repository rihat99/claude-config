# C++ / CUDA Standards (C++17)

Match the surrounding project's style first (its `.clang-format`, naming, include layout). These rules fill the gaps.

## Naming

- `snake_case` — functions, variables, namespaces, files.
- `PascalCase` — classes, structs, enum classes, template parameters (`ScalarType`, not `T_s`).
- `SCREAMING_SNAKE_CASE` — compile-time constants and enum values.

## Modern C++

- `auto` when the type is obvious at the call site; spell it out otherwise.
- `const` for anything that doesn't change; `constexpr` for compile-time values.
- Range-based for: `for (const auto& item : container)`.
- Ownership through `std::unique_ptr` / `std::shared_ptr`. No raw owning pointers.
- RAII for every resource. `std::move` / `std::forward` where it matters.
- Pass non-trivial types by `const T&` unless you need a copy.
- Initialize at declaration. Prefer stack allocation.

## Organization

- Headers: `#pragma once`, minimal includes, forward declarations where possible.
- One main class per header/source pair.
- No magic numbers: named constants.
- Single responsibility per function; early returns over deep nesting.

## Errors

- Exceptions for exceptional cases only; never for control flow.
- In performance-critical code (kernels, hot loops) prefer error codes.
- `assert()` for debug invariants, `static_assert()` for compile-time ones.
- Validate parameters at public API boundaries; trust internal callers.

## CUDA

- `__device__ __forceinline__` for small device helpers on hot paths.
- Check the return code of every CUDA API call (memory, launch, sync).
- `__shared__` memory with attention to bank conflicts; `__syncthreads()` wherever threads exchange data.
- Explicit `CUDA_VISIBLE_DEVICES` for every run; state it in notes.
- Test kernels through the public function that wraps them, not in isolation.

## Documentation

- Public functions: what it does, params, returns, template constraints.
- Complex algorithms: a short comment with the math or the reference.
- No comments that restate the code.

## Building PyTorch C++/CUDA extensions

From the project root, into the project's own environment (never a bare `pip`, which may belong to another Python):

```bash
export TORCH_CUDA_ARCH_LIST="8.0+PTX"   # adjust to the target GPU
uv pip install -e . --no-build-isolation --python <project python>   # or: <project python> -m pip install -e . --no-build-isolation
```
