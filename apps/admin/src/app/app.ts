import { Component } from '@angular/core';
import { RouterOutlet, RouterLink, RouterLinkActive } from '@angular/router';

import { LayoutImports } from '@/shared/components/layout/layout.imports';
import { NgIcon, provideIcons } from '@ng-icons/core';
import {
  lucideLayoutDashboard,
  lucideUsers,
  lucideBuilding2,
  lucideCalendarDays,
  lucideUserCheck,
  lucideClock,
} from '@ng-icons/lucide';

@Component({
  selector: 'app-root',
  standalone: true,
  imports: [RouterOutlet, RouterLink, RouterLinkActive, ...LayoutImports, NgIcon],
  viewProviders: [
    provideIcons({
      lucideLayoutDashboard,
      lucideUsers,
      lucideBuilding2,
      lucideCalendarDays,
      lucideUserCheck,
      lucideClock,
    }),
  ],
  templateUrl: './app.html',
  styleUrl: './app.scss',
})
export class App {}
