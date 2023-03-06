from decimal import Decimal, ROUND_FLOOR
from typing import Iterable, List, NamedTuple, Union, overload

DecimalLike = Union[int, str, Decimal]


def scalar_to_decimal(x: DecimalLike):
    assert isinstance(x, (Decimal, int, str))
    if isinstance(x, Decimal):
        return x
    return Decimal(x)


def to_decimal(x):
    if isinstance(x, (list, tuple)):
        return [scalar_to_decimal(v) for v in x]
    return scalar_to_decimal(x)


def isinstance_namedtuple(obj) -> bool:
    return (
        isinstance(obj, tuple) and hasattr(obj, "_asdict") and hasattr(obj, "_fields")
    )


@overload
def scale(x: DecimalLike, decimals: int = ...) -> Decimal:
    ...


@overload
def scale(x: Iterable[DecimalLike], decimals: int = ...) -> List[Decimal]:
    ...


@overload
def scale(x: NamedTuple, decimals: int = ...) -> NamedTuple:
    ...


def scale(x, decimals=18):
    if isinstance(x, (list, tuple)):
        return [scale(v, decimals) for v in x]
    if isinstance_namedtuple(x):
        return type(x)(*[scale(v, decimals) for v in x])
    return scale_scalar(x, decimals)


def scale_scalar(x: DecimalLike, decimals: int = 18) -> Decimal:
    return (to_decimal(x) * 10**decimals).quantize(0, rounding=ROUND_FLOOR)
