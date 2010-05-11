/**************************************************************************/
/*                                                                        */
/*  The Why platform for program certification                            */
/*  Copyright (C) 2002-2008                                               */
/*    Romain BARDOU                                                       */
/*    Jean-Fran�ois COUCHOT                                               */
/*    Mehdi DOGGUY                                                        */
/*    Jean-Christophe FILLI�TRE                                           */
/*    Thierry HUBERT                                                      */
/*    Claude MARCH�                                                       */
/*    Yannick MOY                                                         */
/*    Christine PAULIN                                                    */
/*    Yann R�GIS-GIANAS                                                   */
/*    Nicolas ROUSSET                                                     */
/*    Xavier URBAIN                                                       */
/*                                                                        */
/*  This software is free software; you can redistribute it and/or        */
/*  modify it under the terms of the GNU Library General Public           */
/*  License version 2, with the special exception on linking              */
/*  described in file LICENSE.                                            */
/*                                                                        */
/*  This software is distributed in the hope that it will be useful,      */
/*  but WITHOUT ANY WARRANTY; without even the implied warranty of        */
/*  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.                  */
/*                                                                        */
/**************************************************************************/

#include <sys/types.h>
#include <sys/time.h>
#include <sys/resource.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <errno.h>

int main(int argc, char *argv[]) {
  int timelimit, memlimit;
  struct rlimit res;

  if (argc < 4) {
    fprintf(stderr, "usage: %s <time limit in seconds> \
<virtual memory limit in MiB> <command>\n\
a null value sets no limit (keeps the actual limit)\n", argv[0]);
    return 1;
  }

  /* get time limit in seconds from command line */
  timelimit = atoi(argv[1]);

  if (timelimit > 0) {
    /* set the CPU time limit */
    getrlimit(RLIMIT_CPU,&res);
    res.rlim_cur = timelimit;
    setrlimit(RLIMIT_CPU,&res);
  }

  /* get virtual memory limit in MiB from command line */
  memlimit = atol(argv[2]);

  if (memlimit > 0) {
    /* set the CPU time limit */
    getrlimit(RLIMIT_AS,&res);
    res.rlim_cur = memlimit * 1024 * 1024;
    setrlimit(RLIMIT_AS,&res);
  }

  /* execute the command */
  execvp(argv[3],argv+3);
  perror("why-cpulimit exec error");
  return 1;
}

