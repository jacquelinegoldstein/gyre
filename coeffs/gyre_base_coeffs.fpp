! Module   : gyre_base_coeffs
! Purpose  : base structure coefficients (interface)
!
! Copyright 2013 Rich Townsend
!
! This file is part of GYRE. GYRE is free software: you can
! redistribute it and/or modify it under the terms of the GNU General
! Public License as published by the Free Software Foundation, version 3.
!
! GYRE is distributed in the hope that it will be useful, but WITHOUT
! ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
! or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU General Public
! License for more details.
!
! You should have received a copy of the GNU General Public License
! along with this program.  If not, see <http://www.gnu.org/licenses/>.

$include 'core.inc'

module gyre_base_coeffs

  ! Uses

  use core_kinds

  ! No implicit typing

  implicit none

  ! Derived-type definitions

  $define $PROC_DECL $sub
    $local $NAME $1
    procedure(get_1_i), deferred :: get_${NAME}_1
    procedure(get_v_i), deferred :: get_${NAME}_v
    generic, public              :: ${NAME} => get_${NAME}_1, get_${NAME}_v
  $endsub

  type, abstract :: base_coeffs_t
   contains
     private
     $PROC_DECL(V)
     $PROC_DECL(As)
     $PROC_DECL(U)
     $PROC_DECL(c_1)
     $PROC_DECL(Gamma_1)
     $PROC_DECL(nabla_ad)
     $PROC_DECL(delta)
     procedure(conv_freq_i), deferred, public :: conv_freq
  end type base_coeffs_t

  ! Interfaces

  abstract interface

     function get_1_i (this, x) result (y)
       use core_kinds
       import base_coeffs_t
       class(base_coeffs_t), intent(in) :: this
       real(WP), intent(in)             :: x
       real(WP)                         :: y
     end function get_1_i

     function get_v_i (this, x) result (y)
       use core_kinds
       import base_coeffs_t
       class(base_coeffs_t), intent(in) :: this
       real(WP), intent(in)             :: x(:)
       real(WP)                         :: y(SIZE(x))
     end function get_v_i

     function conv_freq_i (this, freq, from_units, to_units) result (conv_freq)
       use core_kinds
       import base_coeffs_t
       class(base_coeffs_t), intent(in) :: this
       complex(WP), intent(in)          :: freq
       character(LEN=*), intent(in)     :: from_units
       character(LEN=*), intent(in)     :: to_units
       complex(WP)                      :: conv_freq
     end function conv_freq_i

  end interface

 ! Access specifiers

  private

  public :: base_coeffs_t

end module gyre_base_coeffs
